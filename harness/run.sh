#!/usr/bin/env bash
# Runs the layer in fake_tf3 on this machine's Vulkan driver (in CI: lavapipe, Mesa's CPU driver),
# with the test upscaler in place of DLSS / FSR, and the Khronos validation layer below ours.
#
#   harness/run.sh [BUILD_DIR] [OUT_DIR]      (defaults: build/harness, logs/harness)
#
# BUILD_DIR comes from:  cmake -S harness -B build/harness -G Ninja && cmake --build build/harness
# Runs, each in its own folder under OUT_DIR:
#   checks     all checks (motion vectors, blit swap, UI, ...) with the validation layer
#   skip_fsr   the same with skip_game_fsr=1, contour_debug=1 and crash_log=1
#   perf       without validation, perf=1: the layer's [perf] report
#   no_layer   fake_tf3 alone, to compare its CPU time per frame with "perf"
#   city_off   perf=1 with 2400 vehicles (1 in 20 moving), object_motion=0 (the default)
#   city_on    the same with object_motion=1: the difference is what object motion costs
# OUT_DIR/summary.md: the checks and the layer's cost in Markdown (CI shows it on the run's page).
# Exit code 0 only if every check passed.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
build="$(cd "${1:-$here/../build/harness}" && pwd)"
out="${2:-$here/../logs/harness}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

export VK_ADD_LAYER_PATH="$build/layer"
export TF3_DLSS_TEST_UPSCALER=1
export TF3_DLSS_CAPTURE=60,140,220
# lavapipe unless told otherwise
if [ -z "${VK_DRIVER_FILES:-}${VK_ICD_FILENAMES:-}" ] && [ -f /usr/share/vulkan/icd.d/lvp_icd.json ]; then
  export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.json
fi
validation=VK_LAYER_KHRONOS_validation
if ! VK_LOADER_LAYERS_ENABLE= vulkaninfo --summary 2>/dev/null | grep -q "$validation"; then
  echo "run.sh: Khronos validation layer not found; running without it" >&2
  validation=""
fi

status=0
run() {  # name, extra cfg lines, layers, fake_tf3 options...
  local name="$1" cfg="$2" layers="$3"
  shift 3
  local dir="$out/$name"
  rm -rf "$dir" && mkdir -p "$dir"
  cp "$here/../tf3_dlss.cfg" "$dir/tf3_dlss.cfg"
  printf '\n# test harness\n%b\n' "$cfg" >> "$dir/tf3_dlss.cfg"
  echo "== $name"
  TF3_DLSS_CAPTURE="${CAP-$TF3_DLSS_CAPTURE}" \
    TF3_DLSS_CFG="$dir/tf3_dlss.cfg" TF3_DLSS_LOG="$dir/tf3_dlss.log" VK_INSTANCE_LAYERS="$layers" \
    "$build/fake_tf3" --out "$dir" "$@" 2>&1 | tee "$dir/fake_tf3.txt"
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && status=1
  grep '^\[perf\]' "$dir/tf3_dlss.log" 2>/dev/null | tail -n 4
  return 0
}
vopt=""
[ -n "$validation" ] && vopt="--validation"
with_val="VK_LAYER_TF3_dlss${validation:+:$validation}"
# jitter=1 and object_motion=1 everywhere (both off by default for now): the checks cover the jittered path and the
# object pass, and the cost runs stay comparable with older builds
run checks "log_every=100\njitter=1\nobject_motion=1" "$with_val" $vopt
run skip_fsr "skip_game_fsr=1\njitter=1\nobject_motion=1\ncontour_debug=1\ncrash_log=1" "$with_val" $vopt
run perf "perf=1\nperf_seconds=5\njitter=1\nobject_motion=1" "VK_LAYER_TF3_dlss"
run no_layer "" "" --no-checks
CAP= run city_off "perf=1\nperf_seconds=5\njitter=1\nobject_motion=0" "VK_LAYER_TF3_dlss" --vehicles 2400 --no-checks
CAP= run city_on "perf=1\nperf_seconds=5\njitter=1\nobject_motion=1" "VK_LAYER_TF3_dlss" --vehicles 2400 --no-checks
echo
echo "CPU time per frame for recording, with and without the layer:"
grep -h 'CPU time per frame' "$out/perf/fake_tf3.txt" "$out/no_layer/fake_tf3.txt"
python3 "$here/summary.py" "$out" > "$out/summary.md" || echo "run.sh: summary.py failed" >&2
echo
[ $status -eq 0 ] && echo "harness: all runs passed" || echo "harness: FAILED (see above and $out)"
exit $status
