# shader_check.py - identify the shaders used by the late post-process / upscale draws.
# Run in RenderDoc with the capture open: Window > Python Scripting > Open this file > Run.
# Writes Projects\tf3-dlss\captures\shader_check.txt and dumps shader sources to captures\shaders\.

import os
import renderdoc as rd

FOCUS_EIDS = [7083, 7144, 7155, 7167, 7186]  # bloom composite, FSR x2, the 4K stretch, first UI draw
SCAN_FROM = 7083                              # count shader reuse from here to the end of the frame
BASE = os.path.join(os.path.expanduser("~"), "Projects", "tf3-dlss", "captures")
OUT = os.path.join(BASE, "shader_check.txt")
DUMP = os.path.join(BASE, "shaders")

STAGES = [("VS", rd.ShaderStage.Vertex), ("PS", rd.ShaderStage.Pixel)]


def _rid(d):
    for path in (("descriptor", "resource"), ("resource",), ("resourceId",)):
        obj = d
        try:
            for p in path:
                obj = getattr(obj, p)
            return obj
        except AttributeError:
            continue
    return None


def _field(d, name):
    for obj in (getattr(d, "descriptor", None), d):
        if obj is not None and hasattr(obj, name):
            return getattr(obj, name)
    return 0


def _fmt_var(v, indent="      "):
    if v.members:
        lines = []
        for m in v.members:
            lines += _fmt_var(m, indent)
        return lines
    n = max(1, v.rows * v.columns)
    t = str(v.type)
    if "UInt" in t:
        vals = list(v.value.u32v)[:n]
    elif "Int" in t:
        vals = list(v.value.s32v)[:n]
    else:
        vals = [round(x, 4) for x in list(v.value.f32v)[:n]]
    return ["%s%s = %s" % (indent, v.name, vals if n > 1 else vals[0])]


def run(controller):
    out = []
    tex = {t.resourceId: t for t in controller.GetTextures()}
    null = rd.ResourceId.Null()

    def desc(rid):
        t = tex.get(rid)
        return "%s %dx%d %s" % (rid, t.width, t.height, t.format.Name()) if t else str(rid)

    draws = []

    def walk(acts):
        for a in acts:
            if a.children:
                walk(a.children)
            if a.flags & (rd.ActionFlags.Drawcall | rd.ActionFlags.Dispatch):
                draws.append(a)

    walk(controller.GetRootActions())
    os.makedirs(DUMP, exist_ok=True)

    # 1) Detail for the focus draws
    focus_ps = {}
    for eid in FOCUS_EIDS:
        controller.SetFrameEvent(eid, True)
        pipe = controller.GetPipelineState()
        out.append("=" * 70)
        out.append("EID %d" % eid)
        for label, stage in STAGES:
            refl = pipe.GetShaderReflection(stage)
            if refl is None:
                out.append("  %s: none" % label)
                continue
            files = list(refl.debugInfo.files) if refl.debugInfo is not None else []
            out.append("  %s shader %s  entry=%s" % (label, refl.resourceId, refl.entryPoint))
            for f in files:
                out.append("     file: %s (%d chars)" % (f.filename, len(f.contents)))
                name = "eid%d_%s_%s" % (eid, label, os.path.basename(f.filename).replace("/", "_") or "unnamed")
                with open(os.path.join(DUMP, name + ".txt"), "w", encoding="utf-8") as fh:
                    fh.write(f.contents)
            if not files:
                out.append("     (no embedded source)")
            if label == "PS":
                focus_ps[eid] = refl.resourceId
            # uniforms (FSR params etc.)
            for i, cb in enumerate(refl.constantBlocks):
                try:
                    bound = pipe.GetConstantBlock(stage, i, 0)
                    vars_ = controller.GetCBufferVariableContents(
                        pipe.GetGraphicsPipelineObject(), refl.resourceId, stage,
                        pipe.GetShaderEntryPoint(stage), i,
                        _rid(bound), _field(bound, "byteOffset"), _field(bound, "byteSize"))
                    out.append("     UBO %s:" % cb.name)
                    for v in vars_:
                        out += _fmt_var(v, "        ")
                except Exception as e:
                    out.append("     UBO %s: (couldn't read: %s)" % (cb.name, e))
        for o in pipe.GetOutputTargets():
            r = _rid(o)
            if r not in (None, null):
                out.append("  OUT  %s" % desc(r))
        try:
            reads = pipe.GetReadOnlyResources(rd.ShaderStage.Pixel)
        except Exception:
            reads = []
        for r in reads:
            rid = _rid(r)
            if rid not in (None, null) and rid in tex:
                out.append("  READ %s" % desc(rid))

    # 2) Is the 7167 pixel shader shared with other draws (e.g. the UI)?
    out.append("=" * 70)
    out.append("Pixel-shader reuse from EID %d to end of frame:" % SCAN_FROM)
    users = {}
    for a in draws:
        if a.eventId < SCAN_FROM:
            continue
        controller.SetFrameEvent(a.eventId, False)
        ps = controller.GetPipelineState().GetShader(rd.ShaderStage.Pixel)
        users.setdefault(ps, []).append(a.eventId)
    for eid, ps in focus_ps.items():
        eids = users.get(ps, [])
        out.append("  PS of EID %d (%s) used by %d draws: %s%s" % (
            eid, ps, len(eids), eids[:15], " ..." if len(eids) > 15 else ""))

    text = "\n".join(out)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(text)
    print("Wrote", OUT)


pyrenderdoc.Replay().BlockInvoke(run)
