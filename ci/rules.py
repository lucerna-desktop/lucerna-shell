#!/usr/bin/env python3
"""Regras do projeto que o qmllint não vê. Cada violação sai como
"arquivo:linha: [regra] mensagem"; com alguma, o script termina com 1.

    ci/rules.py              todas as regras
    ci/rules.py camadas ...  só as dadas

Só a biblioteca padrão do Python.
"""

import fnmatch
import io
import os
import re
import subprocess
import sys
import tempfile
import tokenize
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent

# Pastas que nunca entram, além do que o .gitignore ignora.
SKIP_DIRS = {".git", "ci-out", "__pycache__", ".ruff_cache"}


def gitignore_patterns(root):
    path = root / ".gitignore"
    if not path.exists():
        return []
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
    return [line for line in lines if line and not line.startswith("#")]


def ignored(rel, patterns, is_dir):
    for pattern in patterns:
        if pattern.endswith("/"):
            if is_dir and fnmatch.fnmatch(rel.name, pattern[:-1]):
                return True
        elif fnmatch.fnmatch(rel.name, pattern) or fnmatch.fnmatch(rel.as_posix(), pattern):
            return True
    return False


def repo_files(root):
    """Arquivos do repositório (caminhos relativos), sem o que o .gitignore ignora."""
    patterns = gitignore_patterns(root)
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = Path(dirpath).relative_to(root)
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not ignored(rel_dir / d, patterns, True))
        for name in sorted(filenames):
            rel = rel_dir / name
            if not ignored(rel, patterns, False):
                files.append(rel)
    return files


# As únicas supressões do qmllint aceitas: arquivo -> trechos de código que
# precedem o comentário `// qmllint disable unqualified missing-property`, um por
# linha. O motivo (o grupo `margins` do PanelWindow não vem por inteiro nos
# qmltypes do Quickshell: o qmllint 6.11 acusa `unqualified` e o 6.12,
# `missing-property`; as duas categorias, para o lint passar nos dois) e o
# registro estão no spec do CI (docs/superpowers/specs/2026-09-26-ci-design.md).
QMLLINT_ALLOWED = {
    "features/settings/ui/MonitorConfirm.qml": ("margins.top: 90",),
    "features/osd/ui/Osd.qml": ("margins.bottom: 72",),
    "features/notifications/ui/NotificationPopups.qml": (
        "margins.top: ThemeManager.spacing.small",
        "margins.right: ThemeManager.spacing.small",
    ),
}
QMLLINT_SUPPRESSION = re.compile(r"qmllint\s+(disable|enable)\b")
QMLLINT_ALLOWED_COMMENT = "// qmllint disable unqualified missing-property"


def check_suppressions(root):
    """Toda supressão do qmllint (`qmllint disable` e `enable`) nos .qml tem de
    ser uma das de QMLLINT_ALLOWED: no fim da linha de um dos códigos indicados,
    com o comentário `// qmllint disable unqualified missing-property`."""
    out = []
    for rel in repo_files(root):
        if rel.suffix != ".qml":
            continue
        where = rel.as_posix()
        lines = (root / rel).read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, 1):
            match = QMLLINT_SUPPRESSION.search(line)
            if not match:
                continue
            code = line[: match.start()]
            allowed = QMLLINT_ALLOWED.get(where, ())
            if code.strip() in {a + " //" for a in allowed} and line.rstrip().endswith(QMLLINT_ALLOWED_COMMENT):
                continue
            out.append(
                (
                    where,
                    number,
                    "supressão do qmllint fora da lista: só as registradas no spec "
                    "(docs/superpowers/specs/2026-09-26-ci-design.md) são aceitas; "
                    "conserte o aviso ou registre a exceção no spec e em QMLLINT_ALLOWED do ci/rules.py",
                )
            )
    return out


IMPORT_QS = re.compile(r"^\s*import\s+qs\.([\w.]+)")


def check_layers(root):
    """features/*/ui não importa qs.services; uma feature não importa outra;
    core/ não importa qs.features nem qs.services."""
    out = []
    for rel in repo_files(root):
        if rel.suffix != ".qml":
            continue
        where = rel.as_posix()
        parts = rel.parts
        lines = (root / rel).read_text(encoding="utf-8").splitlines()
        for number, line in enumerate(lines, 1):
            match = IMPORT_QS.match(line)
            if not match:
                continue
            module = match.group(1).split(".")
            if parts[0] == "core" and module[0] in ("features", "services"):
                out.append((where, number, f"o core não pode importar qs.{module[0]}: ele só depende do Quickshell"))
            if parts[0] == "features" and len(parts) > 2:
                feature = parts[1]
                if module[0] == "features" and len(module) > 1 and module[1] != feature:
                    out.append(
                        (
                            where,
                            number,
                            f'a feature "{feature}" não pode importar outra feature (qs.features.{module[1]}): '
                            "a conversa passa pelo core ou pelos services",
                        )
                    )
                if parts[2] == "ui" and module[0] == "services":
                    out.append(
                        (
                            where,
                            number,
                            f'a ui da feature "{feature}" não pode importar qs.services: use o state da própria feature',
                        )
                    )
    return out


# Texto de terceiros, copiado como veio: não se mexe no espaçamento.
THIRD_PARTY = {"LICENSE", "themes/fonts/Rubik-OFL.txt"}


def check_whitespace(root):
    """Sem tab, sem espaço no fim da linha, com quebra de linha no fim do
    arquivo e sem CRLF, em todo arquivo de texto do repositório."""
    out = []
    for rel in repo_files(root):
        where = rel.as_posix()
        if where in THIRD_PARTY:
            continue
        data = (root / rel).read_bytes()
        if b"\0" in data:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            out.append((where, 1, "não é UTF-8"))
            continue
        if "\r" in text:
            out.append((where, text[: text.index("\r")].count("\n") + 1, "quebra de linha CRLF (use LF)"))
        for number, line in enumerate(text.replace("\r", "").split("\n"), 1):
            if "\t" in line:
                out.append((where, number, "tab (use espaços)"))
            if line != line.rstrip(" \t"):
                out.append((where, number, "espaço no fim da linha"))
        if text and not text.endswith("\n"):
            out.append((where, text.count("\n") + 1, "sem quebra de linha no fim do arquivo"))
    return out


def split_chunk(line, chunk):
    return [(line + i, part) for i, part in enumerate(chunk.split("\n"))]


# Caracteres depois dos quais uma barra abre uma expressão regular, não uma
# divisão. Sem "}": ele fecha tanto um bloco quanto um ${...} de template
# (aninhado ou não), e depois dele o mais comum é divisão ou caminho.
REGEX_BEFORE = set("(,=:[!&|?{;+-*%<>~^")


def js_segments(text):
    """(linha, trecho) de cada comentário e string de um .qml ou .js."""
    out = []
    i, n, line, prev = 0, len(text), 1, ""
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append((line, text[i + 2 : j]))
            i = j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j
            chunk = text[i + 2 : j]
            out += split_chunk(line, chunk)
            line += chunk.count("\n")
            i = j + 2
            continue
        if c in "\"'`":
            j = i + 1
            while j < n and text[j] != c and not (text[j] == "\n" and c != "`"):
                j += 2 if text[j] == "\\" else 1
            chunk = text[i + 1 : j]
            out += split_chunk(line, chunk)
            line += chunk.count("\n")
            # Sem fechar até a quebra de linha: deixa o "\n" para o laço
            # principal contar a linha (senão ela fica atrasada dali em diante).
            i = j if j < n and text[j] == "\n" else j + 1
            prev = c
            continue
        if c == "/" and (prev == "" or prev in REGEX_BEFORE):
            j, in_class = i + 1, False
            while j < n and text[j] != "\n":
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == "[":
                    in_class = True
                elif text[j] == "]":
                    in_class = False
                elif text[j] == "/" and not in_class:
                    break
                j += 1
            # Mesma correção: regex sem fechar até a quebra de linha não pula o "\n".
            i = j if j < n and text[j] == "\n" else j + 1
            prev = "/"
            continue
        if not c.isspace():
            prev = c
        i += 1
    return out


def sh_segments(text):
    """(linha, trecho) dos comentários e strings de um script de shell."""
    out = []
    for number, raw in enumerate(text.split("\n"), 1):
        i, quote, start = 0, None, 0
        while i < len(raw):
            c = raw[i]
            if quote:
                if c == "\\" and quote == '"':
                    i += 2
                    continue
                if c == quote:
                    out.append((number, raw[start:i]))
                    quote = None
            elif c in "'\"":
                quote, start = c, i + 1
            elif c == "#" and (i == 0 or raw[i - 1] in " \t;"):
                out.append((number, raw[i + 1 :]))
                break
            i += 1
        if quote:
            out.append((number, raw[start:]))
    return out


def py_segments(text):
    """(linha, trecho) dos comentários e strings de um .py (pelo tokenize)."""
    kinds = {tokenize.COMMENT, tokenize.STRING}
    if hasattr(tokenize, "FSTRING_MIDDLE"):
        kinds.add(tokenize.FSTRING_MIDDLE)
    out = []
    try:
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            if tok.type in kinds:
                out += split_chunk(tok.start[0], tok.string)
    except (tokenize.TokenError, SyntaxError):
        pass
    return out


FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
INLINE_CODE = re.compile(r"(`+)(.+?)\1")
LINK_TARGET = re.compile(r"\]\([^)]*\)")
URL = re.compile(r"<?https?://\S+")


def md_outside_fences(text):
    """(linha, linha crua) de um .md fora dos blocos cercados por ``` ou ~~~
    (uma cerca só fecha com o mesmo caractere e pelo menos o mesmo tamanho da
    que abriu, então uma cerca menor aninhada não fecha a de fora)."""
    out, fence = [], None
    for number, line in enumerate(text.split("\n"), 1):
        match = FENCE.match(line)
        if fence:
            if (
                match
                and match.group(1)[0] == fence[0]
                and len(match.group(1)) >= len(fence)
                and not line.strip()[len(match.group(1)) :]
            ):
                fence = None
            continue
        if match:
            fence = match.group(1)
            continue
        out.append((number, line))
    return out


def md_segments(text):
    """(linha, texto) de um .md fora dos blocos de código, sem código inline,
    destinos de link e URLs."""
    out = []
    for number, line in md_outside_fences(text):
        clean = URL.sub(" ", LINK_TARGET.sub("] ", INLINE_CODE.sub(" ", line)))
        if clean.strip():
            out.append((number, clean))
    return out


NO_ACCENT = "não existe sem acento em português"

# Palavra sem acento → por que ela é sempre erro nos textos do Lucerna
# (comentários, strings e documentação; identificadores e caminhos ficam de
# fora pela fronteira de palavra, e siglas em maiúsculas não contam).
WORDS = {
    "nao": NO_ACCENT,
    "voce": NO_ACCENT,
    "voces": NO_ACCENT,
    "tambem": NO_ACCENT,
    "entao": NO_ACCENT,
    "sao": NO_ACCENT,
    "estao": NO_ACCENT,
    "ate": "em português é sempre 'até'; o 'ate' do inglês não aparece nos textos",
    "ja": "em português é sempre 'já'; códigos como ja-JP ficam de fora pelo hífen",
    "so": "em português é 'só'; o 'so' do inglês não aparece nos textos, e 'SO' maiúsculo fica de fora",
    "configuracao": NO_ACCENT,
    "configuracoes": NO_ACCENT,
    "funcao": NO_ACCENT,
    "funcoes": NO_ACCENT,
    "padrao": NO_ACCENT,
    "padroes": NO_ACCENT,
    "opcao": NO_ACCENT,
    "opcoes": NO_ACCENT,
    "informacao": NO_ACCENT,
    "informacoes": NO_ACCENT,
    "sessao": NO_ACCENT,
    "versao": NO_ACCENT,
    "botao": NO_ACCENT,
    "botoes": NO_ACCENT,
    "conexao": NO_ACCENT,
    "acao": NO_ACCENT,
    "acoes": NO_ACCENT,
    "animacao": NO_ACCENT,
    "animacoes": NO_ACCENT,
    "transparencia": NO_ACCENT,
    "preferencias": NO_ACCENT,
    "calendario": NO_ACCENT,
    "codigo": NO_ACCENT,
    "numero": NO_ACCENT,
    "pagina": NO_ACCENT,
    "proximo": NO_ACCENT,
    "proxima": NO_ACCENT,
    "ultimo": NO_ACCENT,
    "ultima": NO_ACCENT,
    "possivel": NO_ACCENT,
    "usuario": NO_ACCENT,
    "usuarios": NO_ACCENT,
    "necessario": NO_ACCENT,
    "midia": NO_ACCENT,
    "musica": NO_ACCENT,
    "musicas": NO_ACCENT,
    "saida": NO_ACCENT,
    "silencio": NO_ACCENT,
    "memoria": NO_ACCENT,
}

WORD = re.compile(r"(?<![\w./\\-])(" + "|".join(sorted(WORDS, key=len, reverse=True)) + r")(?![\w/\\-]|\.\w)", re.I)

# Arquivos que contêm a lista (ou exemplos dela) de propósito.
SELF = {"ci/rules.py", "ci/tests/test_rules.py"}

SEGMENTS = {".qml": js_segments, ".js": js_segments, ".sh": sh_segments, ".py": py_segments, ".md": md_segments}


def check_accents(root):
    """Palavras comuns sem acento em strings e comentários (.qml, .js, .sh,
    .py) e no texto dos .md, fora de código."""
    out = []
    for rel in repo_files(root):
        where = rel.as_posix()
        extract = SEGMENTS.get(rel.suffix)
        if not extract or where in SELF:
            continue
        for number, segment in extract((root / rel).read_text(encoding="utf-8")):
            for match in WORD.finditer(segment):
                word = match.group(1)
                lower = word.lower()
                if word not in (lower, lower.capitalize()):
                    continue
                out.append((where, number, f'"{word}" sem acento ({WORDS[lower]})'))
    return out


MD_LINK = re.compile(r"!?\[[^\]]*\]\((<[^>]+>|[^)\s]+)(?:\s+\"[^\"]*\")?\)")
# Definição de referência: "[ref]: caminho "título opcional"", até 3 espaços
# de indentação, do jeito que o commonmark aceita.
REF_LINK = re.compile(r'^ {0,3}\[[^\]]+\]:\s*(<[^>]+>|\S+)(?:\s+"[^"]*")?\s*$')
SCHEME = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")


def _check_target(root, rel, number, raw_target, out):
    target = raw_target.strip("<>")
    if SCHEME.match(target) or target.startswith("#") or target.startswith("//"):
        return
    path = unquote(target.split("#", 1)[0].split("?", 1)[0])
    if not path:
        return
    base = root if path.startswith("/") else root / rel.parent
    if not (base / path.lstrip("/")).exists():
        out.append((rel.as_posix(), number, f"link para arquivo que não existe: {target}"))


def check_links(root):
    """Imagens, arquivos e definições de referência citados nos .md
    (links relativos) existem."""
    out = []
    for rel in repo_files(root):
        if rel.suffix != ".md":
            continue
        text = (root / rel).read_text(encoding="utf-8")
        for number, line in md_outside_fences(text):
            for link in MD_LINK.finditer(INLINE_CODE.sub(" ", line)):
                _check_target(root, rel, number, link.group(1), out)
            ref = REF_LINK.match(line)
            if ref:
                _check_target(root, rel, number, ref.group(1), out)
    return out


def compare_generated(generated, committed, pattern, hint, root):
    """Cada arquivo gerado tem de ser igual, byte a byte, ao do repositório."""
    out = []
    for new in sorted(generated.glob(pattern)):
        old = committed / new.name
        where = old.relative_to(root).as_posix()
        if not old.exists():
            out.append((where, 1, f"não existe: {hint}"))
        elif old.read_bytes() != new.read_bytes():
            out.append((where, 1, f"desatualizado: {hint}"))
    return out


def run_generator(command, what):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        return [(what, 1, f"o gerador falhou: {(result.stderr or result.stdout).strip()}")]
    return []


# O .qsb depende da versão do qsb: recompilar com o mesmo do CI (o container
# archlinux:latest do dev/ci.sh), nunca com o da máquina.
SHADER_HINT = (
    "recompile com o qsb do CI (dev/ci.sh shell rules e, lá dentro, bash dev/shaders.sh) e faça commit do .qsb"
)


# As pastas de shaders que o dev/shaders.sh compila (o mesmo caminho no repositório
# e dentro da pasta que ele recebe).
SHADER_DIRS = ("themes/shaders", "core/widgets/shaders")


def check_generated_shaders(generated, root):
    """Os .qsb gerados (em `generated`, nas mesmas pastas do repositório)
    contra os do repositório, e os .qsb órfãos."""
    out = []
    for folder in SHADER_DIRS:
        shaders = root / folder
        made = generated / folder
        if not made.is_dir() or not any(made.glob("*.qsb")):
            missing = f"o gerador não produziu nenhum .qsb em {folder} (sumiram os .frag, ou o qsb falhou calado)"
            out.append(("dev/shaders.sh", 1, missing))
            continue
        out += compare_generated(made, shaders, "*.qsb", SHADER_HINT, root)
        for qsb in sorted(shaders.glob("*.qsb")):
            if not qsb.with_suffix(".frag").exists():
                where = qsb.relative_to(root).as_posix()
                out.append((where, 1, f"órfão: não existe {qsb.stem}.frag; apague o .qsb ou devolva o .frag"))
    return out


def check_generated_themes(generated, root):
    """Os JSON gerados (em `generated`) contra themes/*.json."""
    if not any(generated.glob("*.json")):
        return [("dev/themes.py", 1, "o gerador não produziu nenhum JSON de tema")]
    return compare_generated(generated, root / "themes", "*.json", "rode dev/themes.py e faça commit do JSON", root)


def check_shaders(root):
    """Recompila os .frag (SHADER_DIRS) como o dev/shaders.sh e compara com os .qsb."""
    with tempfile.TemporaryDirectory() as tmp:
        failed = run_generator(["bash", str(root / "dev" / "shaders.sh"), tmp], "dev/shaders.sh")
        return failed or check_generated_shaders(Path(tmp), root)


def check_themes(root):
    """Gera os JSON dos temas embutidos pelo dev/themes.py e compara com themes/*.json."""
    with tempfile.TemporaryDirectory() as tmp:
        failed = run_generator([sys.executable, str(root / "dev" / "themes.py"), "--json", tmp], "dev/themes.py")
        return failed or check_generated_themes(Path(tmp), root)


RULES = {
    "camadas": check_layers,
    "supressões": check_suppressions,
    "espaços": check_whitespace,
    "acentos": check_accents,
    "links": check_links,
    "shaders": check_shaders,
    "temas": check_themes,
}


def write_summary(violations):
    out = os.environ.get("CI_OUT")
    if not out:
        return
    Path(out).mkdir(parents=True, exist_ok=True)
    with open(Path(out) / "summary.md", "a", encoding="utf-8") as f:
        f.write("## Regras\n\n")
        if not violations:
            f.write("Nenhuma violação.\n")
        for path, line, msg in violations:
            f.write(f"- `{path}:{line}`: {msg}\n")


def main(argv):
    names = argv or list(RULES)
    unknown = [n for n in names if n not in RULES]
    if unknown:
        print(f"regra desconhecida: {', '.join(unknown)} (use {', '.join(RULES)})", file=sys.stderr)
        return 2
    violations = []
    for name in names:
        violations += [(path, line, f"[{name}] {msg}") for path, line, msg in RULES[name](ROOT)]
    violations.sort()
    for path, line, msg in violations:
        print(f"{path}:{line}: {msg}")
    print(f"regras: {len(violations)} violação(ões)" if violations else "regras: nenhuma violação")
    write_summary(violations)
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
