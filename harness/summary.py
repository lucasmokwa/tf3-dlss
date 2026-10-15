#!/usr/bin/env python3
"""Writes a Markdown summary of a harness/run.sh run: the checks, and what the layer costs.

    harness/summary.py OUT_DIR [BASELINE_METRICS_JSON] > summary.md

Reads OUT_DIR/<run>/result.json (fake_tf3) and the last [perf] report in OUT_DIR/perf/tf3_dlss.log,
and writes the cost numbers to OUT_DIR/metrics.json. With a metrics.json from an earlier run (CI
passes the latest main build's), the cost tables get that run's numbers and the change next to them.
The numbers are from Mesa's CPU driver (lavapipe) on a CI runner: compare them between runs, not
with a real GPU, and expect a few percent of noise.
"""
import json
import re
import sys
from pathlib import Path

out = Path(sys.argv[1] if len(sys.argv) > 1 else "logs/harness")
base = None
if len(sys.argv) > 2:
    try:
        base = json.loads(Path(sys.argv[2]).read_text())
    except (OSError, ValueError):
        base = None


def result(name):
    try:
        return json.loads((out / name / "result.json").read_text())
    except (OSError, ValueError):
        return None


def last_perf_report(log):
    """The last complete [perf] report: its header line and the lines indented under it."""
    try:
        lines = [l.rstrip() for l in log.read_text(errors="replace").splitlines() if l.startswith("[perf]")]
    except OSError:
        return []
    starts = [i for i, l in enumerate(lines) if re.match(r"\[perf\] [\d.]+ s, \d+ frames", l)]
    return lines[starts[-1]:] if starts else []


# ---- numbers
perf, nolayer = result("perf"), result("no_layer")
report = last_perf_report(out / "perf" / "tf3_dlss.log")
m = {"record_ms": {}, "layer_ms": {}, "calls": {}, "lock": {}}
if perf and nolayer:
    m["record_ms"] = {"without the layer": nolayer.get("record_ms"), "with the layer": perf.get("record_ms")}
    if all(isinstance(v, (int, float)) for v in m["record_ms"].values()):
        m["record_ms"]["the layer adds"] = perf["record_ms"] - nolayer["record_ms"]
for line in report:
    r = re.search(r"layer CPU: ([\d.]+) ms per frame.*?\): (.*)", line)
    if r:
        m["layer_ms"]["all"] = float(r.group(1))
        for part in r.group(2).split(", "):
            p = re.match(r"(.+?) ([\d.]+) \((\d+) calls\)", part)
            if p:
                m["layer_ms"][p.group(1)] = float(p.group(2))
                m["calls"][p.group(1)] = int(p.group(3))
    r = re.search(r"waited for the layer's lock (\d+) times per frame, ([\d.]+) ms", line)
    if r:
        m["lock"] = {"waits per frame": int(r.group(1)), "ms waiting": float(r.group(2))}
(out / "metrics.json").write_text(json.dumps(m, indent=2) + "\n")


def num(v, unit=" ms"):
    if isinstance(v, int) and unit == "":
        return str(v)
    return f"{v:.3f}{unit}" if isinstance(v, (int, float)) else "n/a"


def change(now, was):
    if not isinstance(now, (int, float)) or not isinstance(was, (int, float)):
        return ""
    d = now - was
    pct = f" ({d / was * 100:+.0f}%)" if was else ""
    return (f"{d:+d}" if isinstance(d, int) else f"{d:+.3f}") + pct


def table(title, section, unit=" ms", bold=()):
    """A cost table: name, this run, and with a baseline: main and the change."""
    rows = m[section]
    if not rows:
        return []
    was = (base or {}).get(section, {})
    head = f"| {title} | this run |" + (" main | change |" if base else "")
    t = [head, "|---|---|" + ("---|---|" if base else "")]
    for k, v in rows.items():
        name, val = (f"**{k}**", f"**{num(v, unit)}**") if k in bold else (k, num(v, unit))
        t.append(f"| {name} | {val} |" + (f" {num(was.get(k), unit)} | {change(v, was.get(k))} |" if base else ""))
    return t + [""]


# ---- Markdown
md = ["## Test harness", "", "| run | result |", "|---|---|"]
failed = []
for name in ("checks", "skip_fsr", "perf"):
    r = result(name)
    if r is None:
        md.append(f"| {name} | no result (crashed or didn't run) |")
        failed.append(f"{name}: no result")
        continue
    bad = [c for c in r.get("checks", []) if not c.get("pass")]
    md.append(f"| {name} | {'pass' if not bad else f'**{len(bad)} failed**'} ({len(r.get('checks', []))} checks) |")
    failed += [f"{name}: {c['name']}: {c['detail']}" for c in bad]
md.append("")
if failed:
    md += ["Failed:", ""] + [f"- {f}" for f in failed] + [""]

md += ["### What the layer costs", ""]
if perf:
    md += [f"fake_tf3: {perf.get('draws')} draws per frame recorded on several threads, "
           f"{perf['render'][0]}x{perf['render'][1]} -> {perf['output'][0]}x{perf['output'][1]}, "
           f"on {perf.get('gpu')}. "
           + ("Compared with the latest build of main." if base else "No main build to compare with yet."), ""]
md += table("CPU time per frame, recording", "record_ms", bold=("the layer adds",))
md += table("layer CPU per frame (its `[perf]` report)", "layer_ms", bold=("all",))
md += table("lock", "lock", unit="")
if m["calls"]:
    md += ["Calls per frame: " + ", ".join(f"{k} {v}" for k, v in m["calls"].items()) + ".", ""]
if report:
    md += ["<details><summary>Full [perf] report</summary>", "", "```"] + report + ["```", "", "</details>", ""]
else:
    md += ["No `[perf]` report in perf/tf3_dlss.log.", ""]
md += ["CPU driver on a shared CI runner: compare these numbers between runs, not with a game on a GPU, "
       "and expect a few percent of noise. GPU times in the full report are CPU time on this driver."]
print("\n".join(md))
