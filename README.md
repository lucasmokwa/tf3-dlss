# TF3-DLSS

NVIDIA DLSS and AMD FSR 3.1 for **Transport Fever 3**. The mod replaces the game's built-in FSR 1
upscaler for a sharper, steadier image at the same frame rate, or more frames for the same image.
Unofficial and experimental; not affiliated with Urban Games, NVIDIA or AMD.

**[⬇ Download the latest release](https://github.com/lucasmokwa/tf3-dlss/releases/latest)**

## Install

You need Windows 10 or 11 and Transport Fever 3 on Steam. DLSS needs an NVIDIA RTX card (20 series or
newer); FSR 3.1 works on any GPU, and the mod picks the right one for you.

1. Unzip the `TF3-DLSS` folder somewhere it can stay, for example `C:\Games\TF3-DLSS`. Not inside
   `Program Files`.
2. Double-click `install.bat`. It registers the mod for your Windows user: no administrator rights,
   no game files changed. If Windows asks whether to run it, choose *Run*.
3. Start the game from Steam and pick a **Resolution scale** in its graphics options:
   67% (Quality) or 50% (Performance) for more frames, or 100% for native-resolution anti-aliasing
   (DLAA).

In game, **Ctrl+Shift+D** turns the upscaler on and off (to compare with the game's own) and
**Ctrl+Shift+U** switches between DLSS and FSR. Settings are in `tf3_dlss.cfg` in the mod folder;
every line is explained there.

**Update:** close the game and replace the folder's contents with the new zip's. If the folder moved,
run `install.bat` again from the new place.
**Uninstall:** double-click `uninstall.bat`, then delete the folder.
**Not working?** See `README.txt` in the folder. If the mod couldn't start, it leaves a
`TF3-DLSS-DID-NOT-START.txt` there that says why. Bug reports: attach `tf3_dlss.log` from the same
folder, with your GPU and resolution scale.

### Why is there an install script?

Vulkan games don't load a DLL dropped into the game folder. The Vulkan loader only loads layers
registered under `HKCU\SOFTWARE\Khronos\Vulkan\ImplicitLayers`, by the absolute path of the layer's
`.json` file, so something has to write that path once. `install.bat` runs `bin\tf3_dlss_setup.ps1`,
which writes that one registry value; `uninstall.bat` removes it. The layer is then offered to every
Vulkan program but switches itself off in everything except `TransportFever3.exe`.

## Known limitations

- People and animals (skinned models) get camera motion only.
- Smoke, clouds and other effects without depth get no motion vectors and can trail.
- Vulkan renderer only (TF3's only renderer).

---

The rest of this page is for developers.

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

Every push to `main` is released by GitHub Actions (`.github/workflows/release.yml`), as the next
minor version after the latest release (0.2.0, 0.3.0, ...). Pushes that only change Markdown files
are skipped. The workflow stamps the version into its own copy of `layer.cpp`, the manifests and
`package/README.txt`, runs `package.ps1` and publishes `TF3-DLSS-<version>.zip`; nothing is committed
back and binaries are never committed.

For a bigger jump (say 1.0.0), set `TF3_DLSS_VERSION` in `layer/src/layer.cpp` to it: a version newer
than the latest release is used as is. Before pushing, make sure `tf3_dlss.cfg` has the developer
options off, or the package step fails.

The CI build fetches the DLSS SDK from [NVIDIA/DLSS](https://github.com/NVIDIA/DLSS) at the tag in
`DLSS_SDK_REF`, the Vulkan SDK from LunarG and the FSR runtime with `get_fsr.ps1`. Pull requests get the
same build, with the zip under the run's artifacts instead of a release.

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

## License

MIT for the code in this repository (see `LICENSE`). The DLSS and FSR runtimes in releases come
under their own licences; see `package/licenses/THIRD-PARTY.txt`.

This software contains source code provided by NVIDIA Corporation. NVIDIA, RTX and DLSS are
trademarks of NVIDIA Corporation; AMD, FidelityFX and FSR are trademarks of Advanced Micro
Devices, Inc.
