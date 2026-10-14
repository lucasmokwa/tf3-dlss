// Linux test build only: stand-ins for NVIDIA's NGX library, which ships for Windows.
// Every call fails, so the layer reports DLSS as unavailable and the harness runs the
// test upscaler (TF3_DLSS_TEST_UPSCALER=1) or FSR's failure path instead.
#include <vulkan/vulkan.h>
#include "nvsdk_ngx_vk.h"

static const NVSDK_NGX_Result kFail = NVSDK_NGX_Result_Fail;

NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_RequiredExtensions(unsigned int* ic, const char*** ie, unsigned int* dc, const char*** de)
{
    if (ic) *ic = 0; if (ie) *ie = nullptr; if (dc) *dc = 0; if (de) *de = nullptr;
    return kFail;
}
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_Init_with_ProjectID(const char*, NVSDK_NGX_EngineType, const char*, const wchar_t*, VkInstance, VkPhysicalDevice, VkDevice, PFN_vkGetInstanceProcAddr, PFN_vkGetDeviceProcAddr, const NVSDK_NGX_FeatureCommonInfo*, NVSDK_NGX_Version) { return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_Shutdown1(VkDevice) { return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_GetCapabilityParameters(NVSDK_NGX_Parameter** p) { if (p) *p = nullptr; return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_DestroyParameters(NVSDK_NGX_Parameter*) { return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_CreateFeature(VkCommandBuffer, NVSDK_NGX_Feature, NVSDK_NGX_Parameter*, NVSDK_NGX_Handle** h) { if (h) *h = nullptr; return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_CreateFeature1(VkDevice, VkCommandBuffer, NVSDK_NGX_Feature, NVSDK_NGX_Parameter*, NVSDK_NGX_Handle** h) { if (h) *h = nullptr; return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_ReleaseFeature(NVSDK_NGX_Handle*) { return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_VULKAN_EvaluateFeature_C(VkCommandBuffer, const NVSDK_NGX_Handle*, const NVSDK_NGX_Parameter*, PFN_NVSDK_NGX_ProgressCallback_C) { return kFail; }
NVSDK_NGX_Result NVSDK_CONV NVSDK_NGX_Parameter_GetI(NVSDK_NGX_Parameter*, const char*, int* v) { if (v) *v = 0; return kFail; }
void NVSDK_CONV NVSDK_NGX_Parameter_SetF(NVSDK_NGX_Parameter*, const char*, float) {}
void NVSDK_CONV NVSDK_NGX_Parameter_SetI(NVSDK_NGX_Parameter*, const char*, int) {}
void NVSDK_CONV NVSDK_NGX_Parameter_SetUI(NVSDK_NGX_Parameter*, const char*, unsigned int) {}
void NVSDK_CONV NVSDK_NGX_Parameter_SetVoidPointer(NVSDK_NGX_Parameter*, const char*, void*) {}
