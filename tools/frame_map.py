# frame_map.py - summarise a RenderDoc capture into a readable frame graph.
# Run inside RenderDoc: open the capture, then Window > Python Shell > Run Script (or paste),
# and it writes frame_map.txt next to this script (Projects\tf3-dlss\captures\frame_map.txt).
#
# Groups consecutive draws that write the same render targets into "passes" and lists, for each:
# event range, draw count, colour outputs, depth target, and the textures read (with size/format).

import os
import renderdoc as rd

OUT_DIR = os.path.join(os.path.expanduser("~"), "Projects", "tf3-dlss", "captures")
OUT = os.path.join(OUT_DIR, "frame_map.txt")


def _rid(d):
    """Get a ResourceId from the various descriptor wrappers across RenderDoc versions."""
    for path in (("descriptor", "resource"), ("resource",), ("resourceId",)):
        obj = d
        try:
            for p in path:
                obj = getattr(obj, p)
            return obj
        except AttributeError:
            continue
    return None


def _ro_ids(pipe, stage):
    ids = []
    try:
        res = pipe.GetReadOnlyResources(stage)
    except Exception:
        return ids
    for r in res:
        rid = _rid(r)
        if rid is not None:
            ids.append(rid)
            continue
        for sub in getattr(r, "resources", []) or []:  # older BoundResourceArray
            rid = _rid(sub)
            if rid is not None:
                ids.append(rid)
    return ids


def run(controller):
    sfile = controller.GetStructuredFile()
    tex = {t.resourceId: t for t in controller.GetTextures()}
    names = {r.resourceId: r.name for r in controller.GetResources()}
    null = rd.ResourceId.Null()

    def desc(rid):
        t = tex.get(rid)
        if t is None:
            return None
        ms = " msaa%d" % t.msSamp if t.msSamp > 1 else ""
        return "%s %dx%d %s%s" % (names.get(rid, str(rid)), t.width, t.height, t.format.Name(), ms)

    actions = []

    def walk(acts):
        for a in acts:
            if a.children:
                walk(a.children)
            if a.flags & (rd.ActionFlags.Drawcall | rd.ActionFlags.Dispatch):
                actions.append(a)

    walk(controller.GetRootActions())

    passes = []
    cur = None
    for a in actions:
        controller.SetFrameEvent(a.eventId, False)
        pipe = controller.GetPipelineState()
        is_compute = bool(a.flags & rd.ActionFlags.Dispatch)
        if is_compute:
            outs, depth = ("<compute>",), None
            reads = _ro_ids(pipe, rd.ShaderStage.Compute)
        else:
            outs = tuple(str(_rid(o)) for o in pipe.GetOutputTargets() if _rid(o) not in (None, null))
            d = _rid(pipe.GetDepthTarget())
            depth = None if d in (None, null) else d
            reads = _ro_ids(pipe, rd.ShaderStage.Pixel) + _ro_ids(pipe, rd.ShaderStage.Vertex)
        key = (outs, str(depth))
        if cur is None or cur["key"] != key:
            cur = {"key": key, "first": a.eventId, "last": a.eventId, "n": 0,
                   "outs": [] if is_compute else [o for o in pipe.GetOutputTargets() if _rid(o) not in (None, null)],
                   "depth": depth, "reads": set(), "compute": is_compute,
                   "name": a.GetName(sfile)}
            passes.append(cur)
        cur["last"] = a.eventId
        cur["n"] += 1
        cur["reads"].update(r for r in reads if r != null)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("API: %s\nActions: %d  Passes: %d\n\n" % (controller.GetAPIProperties().pipelineType, len(actions), len(passes)))
        for i, p in enumerate(passes):
            f.write("== Pass %d  EID %d-%d  %d %s  first: %s\n" % (
                i, p["first"], p["last"], p["n"], "dispatches" if p["compute"] else "draws", p["name"]))
            for o in p["outs"]:
                f.write("   OUT   %s\n" % desc(_rid(o)))
            if p["depth"] is not None:
                f.write("   DEPTH %s\n" % desc(p["depth"]))
            for r in sorted(p["reads"], key=str):
                d = desc(r)
                if d:
                    f.write("   READ  %s\n" % d)
            f.write("\n")
        f.write("== All textures\n")
        for rid, t in tex.items():
            f.write("   %s\n" % desc(rid))
    print("Wrote", OUT)


def _ok(r):
    """Success check across RenderDoc versions (ResultDetails.OK() vs ReplayStatus/ResultCode enums)."""
    if hasattr(r, "OK"):
        return r.OK()
    for enum in ("ResultCode", "ReplayStatus"):
        if hasattr(rd, enum) and r == getattr(rd, enum).Succeeded:
            return True
    return False


def main():
    # Mode 1: capture path given via env var (PowerShell / command line) -> open it ourselves.
    path = os.environ.get("TF3_CAPTURE")
    if path:
        cap = rd.OpenCaptureFile()
        status = cap.OpenFile(path, "", None)
        if not _ok(status):
            raise RuntimeError("Couldn't open %s: %s" % (path, status))
        result, controller = cap.OpenCapture(rd.ReplayOptions(), None)
        if not _ok(result):
            raise RuntimeError("Couldn't replay %s: %s" % (path, result))
        try:
            run(controller)
        finally:
            controller.Shutdown()
            cap.Shutdown()
        return
    # Mode 2: run from RenderDoc's Python Shell with a capture already open.
    pyrenderdoc.Replay().BlockInvoke(run)


main()
