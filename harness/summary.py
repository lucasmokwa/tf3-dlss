#!/usr/bin/env python3
"""Writes a Markdown summary of a harness/run.sh run: the checks, and what the layer costs.

    harness/summary.py OUT_DIR > summary.md

Reads OUT_DIR/<run>/result.json (fake_tf3) and the last [perf] report in OUT_DIR/perf/tf3_dlss.log.
CI appends it to the run's summary page. The numbers are from Mesa's CPU driver (lavapipe) on a CI
runner: compare them between runs, not with a real GPU.
"""
import json
import re
import sys
from pathlib import Path

out = Path(sys.argv[1] if len(sys.argv) > 1 else "logs/harness")


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


def ms(v):
    return f"{v:.3f} ms" if isinstance(v, (int, float)) else "n/a"


md = ["## Test harness", ""]

# Checks
md += ["| run | result |", "|---|---|"]
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

# Cost
perf, base = result("perf"), result("no_layer")
md += ["### What the layer costs", ""]
if perf and base:
    rec, rec0 = perf.get("record_ms"), base.get("record_ms")
    md += [
        f"fake_tf3: {perf.get('draws')} draws per frame recorded on several threads, "
        f"{perf['render'][0]}x{perf['render'][1]} -> {perf['output'][0]}x{perf['output'][1]}, on {perf.get('gpu')}.",
        "",
        "| CPU time per frame, recording | |",
        "|---|---|",
        f"| without the layer | {ms(rec0)} |",
        f"| with the layer | {ms(rec)} |",
    ]
    if isinstance(rec, (int, float)) and isinstance(rec0, (int, float)):
        md.append(f"| **the layer adds** | **{ms(rec - rec0)}** |")
    md.append("")

report = last_perf_report(out / "perf" / "tf3_dlss.log")
for line in report:
    m = re.search(r"layer CPU: ([\d.]+) ms per frame.*?\): (.*)", line)
    if m:
        md += [f"Layer CPU (its own `[perf]` report): **{m.group(1)} ms per frame**", "",
               "| kind of call | ms per frame | calls per frame |", "|---|---|---|"]
        for part in m.group(2).split(", "):
            p = re.match(r"(.+?) ([\d.]+) \((\d+) calls\)", part)
            if p:
                md.append(f"| {p.group(1)} | {p.group(2)} | {p.group(3)} |")
        md.append("")
    m = re.search(r"waited for the layer's lock (\d+) times per frame, ([\d.]+) ms", line)
    if m:
        md += [f"Lock waits: **{m.group(1)} per frame** ({m.group(2)} ms in all).", ""]
if report:
    md += ["<details><summary>Full [perf] report</summary>", "", "```"] + report + ["```", "", "</details>", ""]
else:
    md += ["No `[perf]` report in perf/tf3_dlss.log.", ""]

md += ["CPU driver on a shared CI runner: compare these numbers between runs, not with a game on a GPU. "
       "GPU times in the full report are CPU time on this driver."]
print("\n".join(md))
