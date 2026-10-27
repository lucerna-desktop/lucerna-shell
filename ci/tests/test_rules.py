"""Testes do ci/rules.py (rodam no job rules: python3 -m unittest discover -s ci/tests)."""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rules  # noqa: E402


class RepoCase(unittest.TestCase):
    def repo(self, files):
        """Cria um repositório de mentira: {caminho: conteúdo (str ou bytes)}."""
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        for rel, content in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(content, bytes):
                path.write_bytes(content)
            else:
                path.write_text(content, encoding="utf-8")
        return root


class RepoFilesTest(RepoCase):
    def test_ignora_gitignore_e_pastas_de_saida(self):
        root = self.repo(
            {
                ".gitignore": ".qmlls.ini\n*.qmlc\n.cache/\n",
                "shell.qml": "",
                ".qmlls.ini": "",
                "core/a.qmlc": "",
                ".cache/x.txt": "",
                "ci-out/lint/qmllint.log": "",
                "ci/__pycache__/rules.cpython-313.pyc": b"\0",
                "Lucerna — Proposta.md": "texto\n",
            }
        )
        files = sorted(p.as_posix() for p in rules.repo_files(root))
        self.assertEqual(files, [".gitignore", "Lucerna — Proposta.md", "shell.qml"])


class LayersTest(RepoCase):
    def test_ui_nao_importa_services(self):
        root = self.repo(
            {"features/bar/ui/Bar.qml": "import QtQuick\nimport qs.features.bar.state\nimport qs.services\n"}
        )
        found = rules.check_layers(root)
        self.assertEqual([(p, n) for p, n, _ in found], [("features/bar/ui/Bar.qml", 3)])
        self.assertIn("qs.services", found[0][2])

    def test_state_pode_importar_services(self):
        root = self.repo({"features/bar/state/BarState.qml": "import qs.services\nimport qs.core.config\n"})
        self.assertEqual(rules.check_layers(root), [])

    def test_feature_nao_importa_outra(self):
        root = self.repo({"features/bar/state/BarState.qml": "import qs.features.dashboard.state\n"})
        found = rules.check_layers(root)
        self.assertEqual(len(found), 1)
        self.assertIn('"bar"', found[0][2])
        self.assertIn("qs.features.dashboard", found[0][2])

    def test_core_nao_importa_features_nem_services(self):
        root = self.repo(
            {
                "core/panels/Panels.qml": "import qs.core.config\nimport qs.services\nimport qs.features.bar.state\n",
            }
        )
        self.assertEqual([n for _, n, _ in rules.check_layers(root)], [2, 3])


class SuppressionsTest(RepoCase):
    OSD = "features/osd/ui/Osd.qml"

    def found(self, files):
        return rules.check_suppressions(self.repo(files))

    def test_aceita_as_registradas(self):
        files = {
            "features/settings/ui/MonitorConfirm.qml": "    margins.top: 90 // qmllint disable unqualified missing-property\n",
            self.OSD: "    margins.bottom: 72 // qmllint disable unqualified missing-property\n",
            "features/notifications/ui/NotificationPopups.qml": (
                "    margins.top: Frame.thickness + ThemeManager.spacing.small // qmllint disable unqualified missing-property\n"
                "    margins.right: Frame.thickness + ThemeManager.spacing.small // qmllint disable unqualified missing-property\n"
            ),
        }
        self.assertEqual(self.found(files), [])

    def test_recusa_a_forma_antiga(self):
        # Só `unqualified` (6.11) deixa passar o `missing-property` do 6.12; o
        # bloco `margins {` não cobre as linhas de dentro, onde o 6.12 acusa.
        popups = "features/notifications/ui/NotificationPopups.qml"
        found = self.found(
            {
                self.OSD: "    margins.bottom: 72 // qmllint disable unqualified\n",
                popups: "Item {\n    margins { // qmllint disable unqualified missing-property\n",
            }
        )
        self.assertEqual(sorted((p, n) for p, n, _ in found), sorted([(self.OSD, 1), (popups, 2)]))

    def test_recusa_disable_sozinho_na_linha(self):
        found = self.found({self.OSD: "Item {\n    // qmllint disable\n    margins.bottom: 72\n}\n"})
        self.assertEqual([(p, n) for p, n, _ in found], [(self.OSD, 2)])
        self.assertIn("spec", found[0][2])

    def test_recusa_outra_categoria(self):
        found = self.found({self.OSD: "    margins.bottom: 72 // qmllint disable missing-property\n"})
        self.assertEqual(len(found), 1)

    def test_recusa_outro_arquivo(self):
        found = self.found(
            {"features/bar/ui/Bar.qml": "    margins.bottom: 72 // qmllint disable unqualified missing-property\n"}
        )
        self.assertEqual([(p, n) for p, n, _ in found], [("features/bar/ui/Bar.qml", 1)])

    def test_recusa_outra_linha_do_arquivo_aceito(self):
        found = self.found({self.OSD: "    width: 10 // qmllint disable unqualified missing-property\n"})
        self.assertEqual(len(found), 1)

    def test_recusa_enable_e_disable_com_texto_depois(self):
        found = self.found(
            {self.OSD: "// qmllint enable unqualified\n    margins.bottom: 72 // qmllint disable unqualified extra\n"}
        )
        self.assertEqual([n for _, n, _ in found], [1, 2])


class WhitespaceTest(RepoCase):
    def test_aponta_tab_espaco_no_fim_crlf_e_falta_de_quebra(self):
        root = self.repo(
            {
                "a.sh": "echo\tx\n",
                "b.qml": "Item {  \n}\n",
                "c.md": "linha\r\noutra\r\n",
                "d.py": "x = 1",
            }
        )
        found = {(p, n, m.split(" (")[0]) for p, n, m in rules.check_whitespace(root)}
        self.assertEqual(
            found,
            {
                ("a.sh", 1, "tab"),
                ("b.qml", 1, "espaço no fim da linha"),
                ("c.md", 1, "quebra de linha CRLF"),
                ("d.py", 1, "sem quebra de linha no fim do arquivo"),
            },
        )

    def test_ignora_binarios_e_terceiros(self):
        root = self.repo(
            {
                "docs/x.png": b"\x89PNG\0\0\t  ",
                "LICENSE": "texto com espaço no fim \n",
                "themes/fonts/Rubik-OFL.txt": "idem \n",
            }
        )
        self.assertEqual(rules.check_whitespace(root), [])

    def test_le_nome_com_espaco_e_acento(self):
        root = self.repo({"Lucerna — Pendências.md": "ok \n"})
        self.assertEqual([(p, n) for p, n, _ in rules.check_whitespace(root)], [("Lucerna — Pendências.md", 1)])


class SegmentsTest(unittest.TestCase):
    def test_js_comentarios_e_strings(self):
        text = (
            'Item {\n    // comentário nao\n    property string a: "texto"\n    x: /"/g.test(b) ? `um\ndois` : 0\n}\n'
        )
        segs = rules.js_segments(text)
        self.assertIn((2, " comentário nao"), segs)
        self.assertIn((3, "texto"), segs)
        self.assertIn((4, "um"), segs)
        self.assertIn((5, "dois"), segs)
        self.assertFalse(any('"' in s for _, s in segs), 'a regex /"/g não abre string')

    def test_sh_comentarios_e_strings_sem_confundir_cerquilha(self):
        segs = rules.sh_segments('echo "${#x} $#" # fim\nn=${v#pre}\n')
        self.assertEqual(segs, [(1, "${#x} $#"), (1, " fim")])

    def test_py_comentarios_e_strings(self):
        segs = rules.py_segments('x = "texto"  # nota\n')
        self.assertEqual([s for _, s in segs], ['"texto"', "# nota"])

    def test_md_pula_codigo_e_links(self):
        text = "Texto `nao` e [link](nao/so.md)\n````\n```\nnao\n```\n````\nfim https://x.so/ja\n"
        segs = rules.md_segments(text)
        self.assertEqual([n for n, _ in segs], [1, 7])
        self.assertNotIn("nao", " ".join(s for _, s in segs))

    def test_md_outside_fences_cerca_aninhada_e_til(self):
        text = "a\n````\n```\nb\n```\n````\nc\n~~~\nd\n~~~\ne"
        segs = rules.md_outside_fences(text)
        self.assertEqual(segs, [(1, "a"), (7, "c"), (11, "e")])

    def test_string_sem_fechar_ate_fim_da_linha_conta_a_quebra(self):
        # Regressão: string entre aspas que não fecha na própria linha não
        # pode "engolir" o "\n" sem contar a linha (senão tudo dali em diante
        # sai numerado uma a menos).
        segs = rules.js_segments('a: \'x\nb: "nao"\n')
        self.assertIn((2, "nao"), segs)

    def test_chave_de_template_aninhado_nao_abre_regex_e_conta_linha_certa(self):
        # Regressão: um "}" que fecha um ${...} de template (aninhado, como em
        # services/Monitors.qml) não pode ser lido como "abre regex" pela
        # barra seguinte — senão o resto da linha (e as linhas depois) saem
        # com a contagem de linha errada.
        text = 'x: `${a || `${"h"}/y`}/z`\nw: "nao"\n'
        segs = rules.js_segments(text)
        self.assertIn((2, "nao"), segs)


class LinksTest(RepoCase):
    def test_links_locais(self):
        root = self.repo(
            {
                "Lucerna — Proposta.md": "x\n",
                "docs/a b.png": b"\0",
                "README.md": (
                    "![foto](docs/a%20b.png) [p](<Lucerna — Proposta.md>) [ext](https://x.org/y)\n"
                    "[ancora](#instalação) [quebrado](docs/nada.png) [sec](README.md#licença)\n"
                    "```\n![no bloco](nada.png)\n```\n"
                    "`[inline](nada.png)`\n"
                ),
                "docs/guia.md": "[sobe](../README.md) [some](../x.md)\n",
            }
        )
        found = sorted((p, n, m.split(": ")[-1]) for p, n, m in rules.check_links(root))
        self.assertEqual(found, [("README.md", 2, "docs/nada.png"), ("docs/guia.md", 1, "../x.md")])

    def test_referencias_e_protocolo_relativo(self):
        root = self.repo(
            {
                "Lucerna — Proposta.md": "x\n",
                "README.md": (
                    "[externo](//cdn.exemplo.com/y)\n"
                    '[ref]: <Lucerna — Proposta.md> "Proposta"\n'
                    "[quebrada]: docs/nada2.png\n"
                    "```\n[bloco]: docs/nada3.png\n```\n"
                ),
            }
        )
        found = sorted((p, n, m.split(": ")[-1]) for p, n, m in rules.check_links(root))
        self.assertEqual(found, [("README.md", 3, "docs/nada2.png")])


class WordBoundaryTest(unittest.TestCase):
    def test_ponto_final_nao_bloqueia_mas_extensao_bloqueia(self):
        self.assertTrue(rules.WORD.search("Isso nao."))
        self.assertTrue(rules.WORD.search("e tambem."))
        self.assertTrue(rules.WORD.search("Ja."))
        self.assertFalse(rules.WORD.search("arquivo so.md"))
        self.assertFalse(rules.WORD.search("nao.qml"))


class AccentsTest(RepoCase):
    def test_acha_palavras_sem_acento(self):
        root = self.repo(
            {
                "core/a.qml": 'Item {\n    // Nao faz nada\n    property string t: "so isso"\n}\n',
                "dev/b.sh": "# configuracao do ambiente\n",
                "c.py": "# funcao\n",
                "d.md": "Voce ja viu?\n",
            }
        )
        found = {(p, n, m.split('"')[1]) for p, n, m in rules.check_accents(root)}
        self.assertEqual(
            found,
            {
                ("core/a.qml", 2, "Nao"),
                ("core/a.qml", 3, "so"),
                ("dev/b.sh", 1, "configuracao"),
                ("c.py", 1, "funcao"),
                ("d.md", 1, "Voce"),
                ("d.md", 1, "ja"),
            },
        )

    def test_ignora_identificadores_caminhos_e_maiusculas(self):
        root = self.repo(
            {
                "core/a.qml": 'Item {\n    property bool nao_existe: true\n    source: "lib/x.so"\n    // O SO do usuário\n}\n',
                "d.md": "Use `nao` e ja-JP\n",
            }
        )
        self.assertEqual(rules.check_accents(root), [])


class GeneratedTest(RepoCase):
    def test_compara_gerados_com_os_do_repositorio(self):
        root = self.repo(
            {
                "novo/a.json": "1\n",
                "novo/b.json": "2\n",
                "novo/c.json": "3\n",
                "themes/a.json": "1\n",
                "themes/b.json": "velho\n",
                "themes/meu.json": "tema do usuário\n",
            }
        )
        found = rules.compare_generated(root / "novo", root / "themes", "*.json", "rode dev/themes.py", root)
        self.assertEqual(
            [(p, m.split(":")[0]) for p, _, m in found],
            [("themes/b.json", "desatualizado"), ("themes/c.json", "não existe")],
        )

    def test_shader_orfao(self):
        root = self.repo(
            {
                "novo/themes/shaders/a.qsb": "A",
                "novo/core/widgets/shaders/b.qsb": "B",
                "themes/shaders/a.frag": "",
                "themes/shaders/a.qsb": "A",
                "themes/shaders/velho.qsb": "V",
                "core/widgets/shaders/b.frag": "",
                "core/widgets/shaders/b.qsb": "B",
                "core/widgets/shaders/antigo.qsb": "X",
            }
        )
        found = rules.check_generated_shaders(root / "novo", root)
        self.assertEqual(
            [(p, m.split(":")[0]) for p, _, m in found],
            [("themes/shaders/velho.qsb", "órfão"), ("core/widgets/shaders/antigo.qsb", "órfão")],
        )

    def test_shader_do_core_desatualizado(self):
        root = self.repo(
            {
                "novo/themes/shaders/a.qsb": "A",
                "novo/core/widgets/shaders/b.qsb": "novo",
                "themes/shaders/a.frag": "",
                "themes/shaders/a.qsb": "A",
                "core/widgets/shaders/b.frag": "",
                "core/widgets/shaders/b.qsb": "velho",
            }
        )
        found = rules.check_generated_shaders(root / "novo", root)
        self.assertEqual([(p, m.split(":")[0]) for p, _, m in found], [("core/widgets/shaders/b.qsb", "desatualizado")])

    def test_gerador_vazio_reprova(self):
        root = self.repo({"themes/shaders/a.frag": "", "themes/shaders/a.qsb": "A", "themes/a.json": "1\n"})
        (root / "vazio").mkdir()
        self.assertEqual([p for p, _, _ in rules.check_generated_shaders(root / "vazio", root)], ["dev/shaders.sh"] * 2)
        self.assertEqual([p for p, _, _ in rules.check_generated_themes(root / "vazio", root)], ["dev/themes.py"])

    def test_dica_manda_regenerar_com_o_qsb_do_ci(self):
        self.assertIn("dev/ci.sh shell rules", rules.SHADER_HINT)


if __name__ == "__main__":
    unittest.main()
