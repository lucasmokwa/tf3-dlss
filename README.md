# TF3-DLSS

DLSS and FSR 3.1 for **Transport Fever 3**, added through a Vulkan layer. The game keeps rendering
at its own (lower) resolution, and the layer replaces the game's built-in FSR 1 upscale with
NVIDIA DLSS (RTX cards) or AMD FSR 3.1 (any GPU).

Unofficial and experimental. Not affiliated with Urban Games, NVIDIA or AMD.

**Players:** download the zip from the [Releases](../../releases) page and follow the `README.txt`
inside. This page is about the source.

## How it works

| Step | What the layer does |
|---|---|
| Find the passes | Recognises the game's tonemap, FSR EASU/RCAS and final blit by their SPIR-V debug names |
| Jitter | Shifts the 3D scene's viewport by a sub-pixel Halton offset each frame (overlays and UI aren't touched) |
| Camera motion | Compute pass: rebuilds each pixel's previous screen position from depth and the camera matrices |
| Object motion | Finds moving models (vehicles) and redraws them into the motion-vector image with last frame's model matrix |
| Upscale | After RCAS, records DLSS or FSR 3.1 into the game's command buffer, then swaps the blit's input for the upscaled image |
| Extras | Texture LOD bias, sharpening (CAS-style for DLSS, RCAS for FSR), hover-highlight depth fix |

The layer is installed as a Vulkan *implicit* layer (one registry value under
`HKCU\SOFTWARE\Khronos\Vulkan\ImplicitLayers`) and fails the loader negotiation in every process
except `TransportFever3.exe`, so other Vulkan programs never load it.

## Repository layout

| Folder | Contents |
|---|---|
| `layer/` | Layer source (`src/layer.cpp`), shaders (`shaders/`), CMake project, layer manifests |
| `scripts/` | `build.ps1`, `run_tf3.ps1` (dev launch), `run_validation.ps1`, `get_fsr.ps1`, `package.ps1` |
| `package/` | Files shipped as-is in a release: `README.txt`, `install.bat`, `uninstall.bat`, `licenses/`, setup script |
| `third_party/ffx-api/` | AMD FidelityFX API headers (MIT); the runtime DLL is downloaded into `bin/`, not committed |
| `tools/` | RenderDoc analysis scripts used during development |
| `tf3_dlss.cfg` | Settings, documented line by line (the release copy) |

## Building

Needs Windows with:

- Visual Studio 2022+ Build Tools (C++), CMake and Ninja
- the [Vulkan SDK](https://vulkan.lunarg.com/)
- the [NVIDIA DLSS SDK](https://github.com/NVIDIA/DLSS) in `%USERPROFILE%\Projects\DLSS` (or set `-DDLSS_SDK=...`)

```powershell
cd scripts
.\get_fsr.ps1        # once: AMD's signed amd_fidelityfx_vk.dll (FidelityFX SDK v1.1.4)
.\build.ps1          # -> build\bin: VkLayer_tf3_dlss.dll, manifests, nvngx_dlss.dll, amd_fidelityfx_vk.dll
.\run_tf3.ps1        # starts TF3 with the layer from build\bin (log: logs\layer.log)
```

`run_tf3.ps1` enables the layer for that launch only and uses the repo's `tf3_dlss.cfg`. If the
release version is also installed with `install.bat`, both register the same layer name and the
Vulkan loader uses one of them, so uninstall the release while developing.

`run_validation.ps1` does the same with the Khronos validation layer below ours
(`-Sync` adds synchronisation validation); messages go to `logs\validation.log`.

## Releasing

1. Bump `TF3_DLSS_VERSION` in `layer/src/layer.cpp`, the manifests' `implementation_version`, and the version in `package/README.txt`.
2. `.\build.ps1`, test, then `.\package.ps1`. That checks the cfg has developer options off and writes `dist\TF3-DLSS-<version>.zip`.
3. Create a GitHub release with that zip attached. Binaries are never committed.

## Hotkeys

| Keys | Does |
|---|---|
| Ctrl+Shift+D | upscaler on / off |
| Ctrl+Shift+U | switch DLSS <-> FSR 3.1 |

With `debug_keys=1` in the cfg:

| Keys | Does |
|---|---|
| Ctrl+Shift+M | motion vectors: camera + objects -> camera only -> off |
| Ctrl+Shift+J | jitter on / off |
| Ctrl+Shift+V | debug view: off -> motion vectors -> jitter |
| Ctrl+Shift+T | automated camera test, recorded to `mvcap/` next to the log |
| Ctrl+Shift+Y | automated quick-tilt test, records 8 frames in a row |
| Ctrl+Shift+L | log every 3D scene draw of one frame (pipeline state) |

## Known limitations

- People and animals (skinned models) get camera motion only.
- Smoke, clouds and other effects without depth get no motion vectors and can trail.
- Vulkan renderer only (TF3's only renderer).

## License

MIT for the code in this repository (see `LICENSE`). The DLSS and FSR runtimes in releases come
under their own licences; see `package/licenses/THIRD-PARTY.txt`.

This software contains source code provided by NVIDIA Corporation. NVIDIA, RTX and DLSS are
trademarks of NVIDIA Corporation; AMD, FidelityFX and FSR are trademarks of Advanced Micro
Devices, Inc.
