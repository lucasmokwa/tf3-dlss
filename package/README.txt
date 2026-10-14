TF3-DLSS 0.1.0  -  DLSS and FSR 3.1 for Transport Fever 3
==========================================================

Replaces the game's built-in upscaler (FSR 1) with NVIDIA DLSS or AMD FSR 3.1,
for a sharper, steadier image at the same render resolution, or the same
image at a lower one. Unofficial mod; not made or endorsed by Urban Games,
NVIDIA or AMD.


REQUIREMENTS
------------
- Windows 10 or 11, Transport Fever 3 (Steam), Vulkan renderer (the default).
- DLSS: an NVIDIA GeForce RTX card (20 series or newer) and a recent driver.
- FSR 3.1: any GPU that runs the game (AMD, Intel or NVIDIA).


INSTALL
-------
1. Open the game folder: in Steam, right-click Transport Fever 3, then
   Manage > Browse local files.
2. Copy everything from the zip into that folder, next to
   TransportFever3.exe: version.dll and the TF3-DLSS folder. No game files
   are replaced, and nothing is installed anywhere else.
3. Start the game as usual and pick a "Resolution scale" in the game's
   graphics options: 67% (Quality) or 50% (Performance) for more frames,
   or 100% for native-resolution anti-aliasing (DLAA, no speed-up).

version.dll is a small stand-in for the Windows file of the same name: the
game loads it from its own folder, it tells Vulkan where the mod is (for this
game only), and passes everything else on to the real version.dll.


UPDATE
------
Close the game and copy the new zip's contents over the old ones.


USING IT
--------
Settings are in tf3_dlss.cfg (open it with Notepad). Every line is explained
there. Most changes apply while the game runs, as soon as you save the file.

To compare with the game's own upscaling, set debug_keys=1 in tf3_dlss.cfg.
Then, in game:
  Ctrl+Shift+D   upscaler on / off (off = the game's own FSR 1)
  Ctrl+Shift+U   switch between DLSS and FSR 3.1 (NVIDIA RTX cards)


CHOOSING AN UPSCALER
--------------------
upscaler=auto is the default: DLSS on NVIDIA RTX cards, FSR 3.1 otherwise.
To use FSR on an NVIDIA card, set upscaler=fsr in tf3_dlss.cfg.

Other useful settings:
  sharpness=0.3       DLSS sharpening, 0 (off) to 1
  fsr_sharpness=0.5   FSR sharpening, 0 (off) to 1
  preset=11       DLSS model (K); 13 (M) can look better at 50% on RTX 40/50
  mip_bias=auto   sharper ground textures; set -1 if fine patterns shimmer


IF SOMETHING IS WRONG
---------------------
- No change in game? Look for TF3-DLSS-DID-NOT-START.txt in this folder (or
  in %TEMP%). It says why the upscaler didn't run, for example DLSS isn't
  available on the GPU (set upscaler=fsr). If there is neither that file nor
  tf3_dlss.log, the mod wasn't loaded: check that version.dll and the
  TF3-DLSS folder are directly next to TransportFever3.exe.
- tf3_dlss.log in this folder (or %TEMP%) has the details. Please attach it
  to any bug report, with your GPU and the render scale you use.
- Smearing or ghosting behind moving things: people and animals currently get
  camera motion only, and smoke/clouds have no depth, so some trails there
  are expected. Anything else: please report it.
- To rule the mod out completely, uninstall it (or set the environment
  variable TF3_DLSS_DISABLE=1).


UNINSTALL
---------
Delete version.dll and the TF3-DLSS folder from the game folder.


CREDITS AND LICENSES
--------------------
Uses NVIDIA DLSS (NVIDIA DLSS SDK) and AMD FSR 3.1 (AMD FidelityFX SDK);
their runtimes are included unmodified.
TF3-DLSS's own source code is MIT licensed (licenses\TF3-DLSS-LICENSE.txt).
The NVIDIA files (bin\nvngx_dlss.dll, and the NVIDIA library inside
bin\VkLayer_tf3_dlss.dll) are not: they may only be used with this mod, not
redistributed on their own, modified or reverse engineered. Full terms in
licenses\THIRD-PARTY.txt.
NVIDIA, RTX and DLSS are trademarks of NVIDIA Corporation. AMD, FidelityFX and
FSR are trademarks of Advanced Micro Devices, Inc.
