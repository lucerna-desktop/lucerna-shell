#!/usr/bin/env python3
"""Leitor do dev/bench-paineis.sh: lê as marcas (marks.tsv), o log do render
loop do Qt (qt.scenegraph.time.renderloop) e os vídeos do wf-recorder, e
imprime a tabela dos painéis. Só a biblioteca padrão (e o ffprobe para os
vídeos).

    dev/bench-paineis.py report MARKS LOG
    dev/bench-paineis.py --self-test

As marcas, uma por linha, separadas por tabulação:
    info   CHAVE   VALOR                          (cabeçalho)
    slice  LINHA   LINHA0  LINHA1  MS             (trecho do log: linhas LINHA0+1..LINHA1)
    cpu    CASO    TICKS_QS  TICKS_HYPR  HZ  MS
    skip   LINHA                                  (linha sem como medir: sai com -)
    video  CASO    ARQUIVO
    vslice LINHA   INÍCIO_MS  MS                  (fatia do vídeo, a partir do início dele)

LINHA é a linha da tabela: o caso, ou <caso>:abrir / <caso>:fechar nos casos
de ciclo. A CPU e o vídeo são do caso inteiro (a parte antes do ":"), então as
duas linhas de um caso de ciclo mostram a mesma CPU.
    rss    antes|depois  KB

Por quadro de uma janela, o custo é o maior entre o `frame rendered in Xms`
(render thread) e a soma polish+lock+blockedForSync+animations do `Frame
prepared` (gui thread) que veio antes dele na mesma janela. Um `Frame prepared`
sem `frame rendered` depois conta no pior, no p95 e nos longos, não nos quadros.
O p95 é o percentil 95 desses custos (pelo posto mais próximo).
"""

import re
import subprocess
import sys

LONG_MS = 20

ANSI = re.compile(r"\x1b\[[0-9;]*m")
RENDERED = re.compile(r"\[window (0x[0-9a-fA-F]+)\]\[render thread [^\]]*\] syncAndRender: frame rendered in (\d+)ms")
PREPARED = re.compile(
    r"\[window (0x[0-9a-fA-F]+)\]\[gui thread\] Frame prepared, "
    r"polish=(\d+) ms, lock=(\d+) ms, blockedForSync=(\d+) ms, animations=(\d+) ms"
)

COLUMNS = ["caso", "FPS shell", "FPS mín", "pior ms", "p95 ms", "longos", "quadros", "qs %", "Hyprland %", "FPS tela"]


def frames(lines):
    """Os quadros de um trecho do log: {janela: n}, e a lista de custos (ms)."""
    per_window = {}
    costs = []
    pending = {}
    for raw in lines:
        line = ANSI.sub("", raw)
        m = PREPARED.search(line)
        if m:
            window = m.group(1)
            if window in pending:
                costs.append(pending[window])
            pending[window] = sum(int(g) for g in m.groups()[1:])
            continue
        m = RENDERED.search(line)
        if m:
            window = m.group(1)
            per_window[window] = per_window.get(window, 0) + 1
            costs.append(max(int(m.group(2)), pending.pop(window, 0)))
    costs.extend(pending.values())
    return per_window, costs


def video_times(path):
    """Os instantes (s) dos quadros gravados no vídeo, pelo ffprobe."""
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "packet=pts_time", "-of", "csv=p=0", path],
        capture_output=True,
        text=True,
        check=True,
    )
    times = []
    for value in result.stdout.split():
        value = value.strip(",")
        if value and value != "N/A":
            times.append(float(value))
    return sorted(times)


def parse_marks(text):
    marks = {"info": [], "order": [], "slices": {}, "cpu": {}, "skip": set(), "video": {}, "vslices": {}, "rss": {}}

    def seen(name):
        if name not in marks["order"]:
            marks["order"].append(name)

    for line in text.splitlines():
        if not line.strip():
            continue
        f = line.split("\t")
        kind = f[0]
        if kind == "info":
            marks["info"].append((f[1], f[2]))
        elif kind == "slice":
            seen(f[1])
            marks["slices"].setdefault(f[1], []).append((int(f[2]), int(f[3]), int(f[4])))
        elif kind == "cpu":
            marks["cpu"][f[1]] = tuple(int(x) for x in f[2:6])
        elif kind == "skip":
            seen(f[1])
            marks["skip"].add(f[1])
        elif kind == "video":
            marks["video"][f[1]] = f[2]
        elif kind == "vslice":
            marks["vslices"].setdefault(f[1], []).append((int(f[2]), int(f[3])))
        elif kind == "rss":
            marks["rss"][f[1]] = int(f[2])
    return marks


def p95(costs):
    """O percentil 95 pelo posto mais próximo, ou None sem custos."""
    if not costs:
        return None
    ordered = sorted(costs)
    return ordered[max(0, -(-95 * len(ordered) // 100) - 1)]


def cpu_pct(ticks, hz, ms):
    return f"{ticks / hz / (ms / 1000) * 100:.1f}" if ms > 0 else "-"


def screen_fps(times, vslices):
    rates = []
    for start_ms, dur_ms in vslices:
        a, b = start_ms / 1000, (start_ms + dur_ms) / 1000
        n = sum(1 for t in times if a <= t < b)
        rates.append(n / (dur_ms / 1000))
    return f"{sum(rates) / len(rates):.1f}" if rates else "-"


def row(name, marks, log_lines, video_reader):
    if name in marks["skip"]:
        return [name] + ["-"] * (len(COLUMNS) - 1)
    case = name.split(":")[0]
    rates = []
    all_costs = []
    total = 0
    for l0, l1, ms in marks["slices"].get(name, []):
        per_window, costs = frames(log_lines[l0:l1])
        best = max(per_window.values(), default=0)
        rates.append(best / (ms / 1000) if ms > 0 else 0)
        all_costs.extend(costs)
        total += sum(per_window.values())
    worst = max(all_costs, default=0)
    pct95 = p95(all_costs)
    pct95 = "-" if pct95 is None else str(pct95)
    long_frames = sum(1 for c in all_costs if c > LONG_MS)
    fps = f"{sum(rates) / len(rates):.1f}" if rates else "-"
    fps_min = f"{min(rates):.1f}" if rates else "-"
    if case in marks["cpu"]:
        q, h, hz, ms = marks["cpu"][case]
        qs, hypr = cpu_pct(q, hz, ms), cpu_pct(h, hz, ms)
    else:
        qs = hypr = "-"
    tela = "-"
    if case in marks["video"] and marks["vslices"].get(name):
        try:
            tela = screen_fps(video_reader(marks["video"][case]), marks["vslices"][name])
        except (OSError, subprocess.CalledProcessError):
            tela = "-"
    return [name, fps, fps_min, str(worst), pct95, str(long_frames), str(total), qs, hypr, tela]


def table(marks, log_lines, video_reader=video_times):
    out = []
    for key, value in marks["info"]:
        out.append(f"{key}: {value}")
    if marks["info"]:
        out.append("")
    rows = [COLUMNS] + [row(name, marks, log_lines, video_reader) for name in marks["order"]]
    widths = [max(len(r[i]) for r in rows) for i in range(len(COLUMNS))]
    for r in rows:
        cells = [r[0].ljust(widths[0])] + [c.rjust(w) for c, w in zip(r[1:], widths[1:])]
        out.append("  ".join(cells).rstrip())
    rss = marks["rss"]
    if rss:
        before = f"{rss['antes'] / 1024:.0f} MB" if "antes" in rss else "-"
        after = f"{rss['depois'] / 1024:.0f} MB" if "depois" in rss else "-"
        out.append(f"RSS do qs: {before} antes, {after} depois")
    return "\n".join(out)


SAMPLE_LOG = """\
\x1b[34m DEBUG\x1b[97m qt.scenegraph.time.renderloop\x1b[0m: [window 0x7f9cb4a318c0][gui thread] polishAndSync: start, elapsed since last call: 3 ms
[window 0x7f9cb4a318c0][gui thread] Frame prepared, polish=1 ms, lock=0 ms, blockedForSync=2 ms, animations=0 ms
[window 0x7f9cb4a318c0][render thread 0x7f9cd0000b70] syncAndRender: frame rendered in 3ms, sync=0, render=2, swap=1
[window 0x7f9cb4a318c0][gui thread] Frame prepared, polish=10 ms, lock=0 ms, blockedForSync=14 ms, animations=1 ms
[window 0x7f9cb4a318c0][render thread 0x7f9cd0000b70] syncAndRender: frame rendered in 5ms, sync=1, render=3, swap=1
[window 0x7f9cb4a40000][render thread 0x7f9cd0001000] syncAndRender: frame rendered in 22ms, sync=9, render=11, swap=2
INFO: outra coisa qualquer
[window 0x7f9cb4a318c0][render thread 0x7f9cd0000b70] syncAndRender: frame rendered in 4ms, sync=0, render=3, swap=1
[window 0x7f9cb4a40000][gui thread] Frame prepared, polish=0 ms, lock=0 ms, blockedForSync=30 ms, animations=0 ms
"""

SAMPLE_MARKS = """\
info\tblur\tperformance
slice\tpainel-superior:abrir\t0\t5\t500
slice\tpainel-superior:fechar\t5\t9\t1000
cpu\tpainel-superior\t50\t100\t100\t2000
video\tpainel-superior\t/x.mkv
vslice\tpainel-superior:abrir\t1000\t500
vslice\tpainel-superior:fechar\t2000\t1000
skip\tosd:abrir
slice\tparado\t9\t9\t10000
cpu\tparado\t0\t10\t100\t10000
rss\tantes\t204800
rss\tdepois\t215040
"""


def self_test():
    lines = SAMPLE_LOG.splitlines(keepends=True)
    per_window, costs = frames(lines)
    assert per_window == {"0x7f9cb4a318c0": 3, "0x7f9cb4a40000": 1}, per_window
    # 3 (prepared 3), 25 (prepared 25 > rendered 5), 22, 4, e o órfão de 30.
    assert costs == [3, 25, 22, 4, 30], costs

    assert p95([]) is None
    assert p95([7]) == 7
    assert p95(list(range(1, 101))) == 95
    assert p95(list(range(20, 0, -1))) == 19

    marks = parse_marks(SAMPLE_MARKS)
    names = ["painel-superior:abrir", "painel-superior:fechar", "osd:abrir", "parado"]
    assert marks["order"] == names, marks["order"]
    times = [0.0, 1.0, 1.1, 1.2, 1.6, 2.0, 2.5, 2.99, 3.0]
    text = table(marks, lines, video_reader=lambda path: times)
    assert text.splitlines()[2].split()[:6] == ["caso", "FPS", "shell", "FPS", "mín", "pior"], text
    rows = {r.split()[0]: r.split()[1:] for r in text.splitlines() if r and r.split()[0] in names}
    # Abrir (linhas 0..5): a janela 318c0 com 2 quadros em 0,5 s = 4/s; custos
    # 3 e 25. Vídeo: 3 quadros em [1; 1,5) = 6/s. CPU do caso inteiro.
    assert rows["painel-superior:abrir"] == ["4.0", "4.0", "25", "25", "1", "2", "25.0", "50.0", "6.0"], rows
    # Fechar (5..9): 1 quadro de cada janela em 1 s = 1/s; custos 22, 4 e o
    # órfão de 30. Vídeo: 3 quadros em [2; 3) = 3/s.
    assert rows["painel-superior:fechar"] == ["1.0", "1.0", "30", "30", "2", "2", "25.0", "50.0", "3.0"], rows
    assert rows["osd:abrir"] == ["-"] * 9, rows["osd:abrir"]
    assert rows["parado"] == ["0.0", "0.0", "0", "-", "0", "0", "0.0", "1.0", "-"], rows["parado"]
    assert "RSS do qs: 200 MB antes, 210 MB depois" in text, text
    assert "blur: performance" in text, text
    print("self-test: ok")


def main(argv):
    if argv[1:] == ["--self-test"]:
        self_test()
        return 0
    if len(argv) == 4 and argv[1] == "report":
        with open(argv[2], encoding="utf-8") as f:
            marks = parse_marks(f.read())
        with open(argv[3], encoding="utf-8", errors="replace") as f:
            log_lines = f.readlines()
        print(table(marks, log_lines))
        return 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
