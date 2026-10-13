# shader_check.py - identify the shaders and FSR constants for the late post-process draws.
# Run in RenderDoc with the capture open: Window > Python Scripting > Open this file > Run.
# Writes Projects\tf3-dlss\captures\shader_check.txt (and prints the same to the Output tab).

import os
import renderdoc as rd

FROM_EID = 7000   # check every draw from here to the end of the frame (post-process + upscale + UI start)
MAX_DRAWS = 40    # stop after this many draws so it stays quick
OUT = os.path.join(os.path.expanduser("~"), "Projects", "tf3-dlss", "captures", "shader_check.txt")


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
    lines = []
    if v.members:
        for m in v.members:
            lines += _fmt_var(m, indent)
        return lines
    n = max(1, v.rows * v.columns)
    t = str(v.type)
    if "Int" in t or "SInt" in t:
        vals = list(v.value.s32v)[:n]
    elif "UInt" in t:
        vals = list(v.value.u32v)[:n]
    else:
        vals = [round(x, 4) for x in list(v.value.f32v)[:n]]
    lines.append("%s%s = %s" % (indent, v.name, vals if n > 1 else vals[0]))
    return lines


def run(controller):
    out = []
    tex = {t.resourceId: t for t in controller.GetTextures()}

    def desc(rid):
        t = tex.get(rid)
        return "%s %dx%d %s" % (rid, t.width, t.height, t.format.Name()) if t else str(rid)

    draws = []

    def walk(acts):
        for a in acts:
            if a.children:
                walk(a.children)
            if a.eventId >= FROM_EID and a.flags & (rd.ActionFlags.Drawcall | rd.ActionFlags.Dispatch):
                draws.append(a)

    walk(controller.GetRootActions())
    null = rd.ResourceId.Null()

    for a in draws[:MAX_DRAWS]:
        controller.SetFrameEvent(a.eventId, True)
        pipe = controller.GetPipelineState()
        refl = pipe.GetShaderReflection(rd.ShaderStage.Pixel)
        files = []
        if refl is not None and refl.debugInfo is not None:
            files = [f.filename for f in refl.debugInfo.files]
        main = [f for f in files if not f.endswith(".glsl")] or files[:1]
        out.append("EID %d  PS main: %s" % (a.eventId, ", ".join(os.path.basename(f) for f in main) or "?"))
        for o in pipe.GetOutputTargets():
            r = _rid(o)
            if r not in (None, null):
                out.append("   OUT  %s" % desc(r))
        try:
            reads = pipe.GetReadOnlyResources(rd.ShaderStage.Pixel)
        except Exception:
            reads = []
        for r in reads:
            rid = _rid(r)
            if rid not in (None, null) and rid in tex and tex[rid].width >= 1000:
                out.append("   READ %s" % desc(rid))

        # Dump uniform values for FSR draws (sourceSize / outputSize / sharpening)
        if refl is not None and any("fsr" in f.lower() for f in files):
            for i, cb in enumerate(refl.constantBlocks):
                try:
                    bound = pipe.GetConstantBlock(rd.ShaderStage.Pixel, i, 0)
                    vars_ = controller.GetCBufferVariableContents(
                        pipe.GetGraphicsPipelineObject(), refl.resourceId, rd.ShaderStage.Pixel,
                        pipe.GetShaderEntryPoint(rd.ShaderStage.Pixel), i,
                        _rid(bound), _field(bound, "byteOffset"), _field(bound, "byteSize"))
                    out.append("   UBO %s:" % cb.name)
                    for v in vars_:
                        out += _fmt_var(v)
                except Exception as e:
                    out.append("   UBO %s: (couldn't read: %s)" % (cb.name, e))
        out.append("")

    text = "\n".join(out)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(text)
    print("Wrote", OUT)


pyrenderdoc.Replay().BlockInvoke(run)
