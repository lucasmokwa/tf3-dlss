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
1. Unzip the TF3-DLSS folder somewhere permanent, for example
   C:\Games\TF3-DLSS. Not inside "Program Files" (the log can't be written
   there).
2. Double-click install.bat. It registers the mod for your Windows user; no
   administrator rights, and no game files are touched. If Windows asks
   whether to run it, choose "Run".
3. Start the game as usual and pick a "Resolution scale" in the game's
   graphics options: 67% (Quality) or 50% (Performance) for more frames,
   or 100% for native-resolution anti-aliasing (DLAA, no speed-up).

If you move or rename the folder later, run uninstall.bat first and
install.bat again from the new place.


UPDATE
------
Close the game and replace this folder's contents with the new zip's. If
you put the new version somewhere else, run install.bat again from there.


USING IT
--------
Ctrl+Shift+D   upscaler on / off (off = the game's own FSR 1, to compare)
Ctrl+Shift+U   switch between DLSS and FSR 3.1 (NVIDIA RTX cards)

Settings are in tf3_dlss.cfg (open it with Notepad). Every line is explained
there. Most changes apply while the game runs, as soon as you save the file.


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
  in %TEMP%). It says why the upscaler didn't run. Common reasons: install.bat
  wasn't run, the folder was moved after installing (run install.bat
  again), or DLSS isn't available on the GPU (set upscaler=fsr).
- tf3_dlss.log in this folder (or %TEMP%) has the details. Please attach it
  to any bug report, with your GPU and the render scale you use.
- Smearing or ghosting behind moving things: people and animals currently get
  camera motion only, and smoke/clouds have no depth, so some trails there
  are expected. Anything else: please report it.
- To rule the mod out completely, run uninstall.bat (or set the environment
  variable TF3_DLSS_DISABLE=1).


UNINSTALL
---------
Double-click uninstall.bat, then delete this folder.


CREDITS AND LICENSES
--------------------
TF3-DLSS: MIT license, see licenses\TF3-DLSS-LICENSE.txt.
Uses the NVIDIA DLSS SDK and the AMD FidelityFX SDK (FSR 3.1); their
runtimes are included unmodified. See licenses\THIRD-PARTY.txt.
NVIDIA, RTX and DLSS are trademarks of NVIDIA Corporation. AMD, FidelityFX and
FSR are trademarks of Advanced Micro Devices, Inc.
