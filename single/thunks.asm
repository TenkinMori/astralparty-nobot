EXTERN g_targets:QWORD
.code

HidD_FlushQueue PROC
    jmp qword ptr [g_targets + 0]
HidD_FlushQueue ENDP

HidD_FreePreparsedData PROC
    jmp qword ptr [g_targets + 8]
HidD_FreePreparsedData ENDP

HidD_GetAttributes PROC
    jmp qword ptr [g_targets + 16]
HidD_GetAttributes ENDP

HidD_GetConfiguration PROC
    jmp qword ptr [g_targets + 24]
HidD_GetConfiguration ENDP

HidD_GetFeature PROC
    jmp qword ptr [g_targets + 32]
HidD_GetFeature ENDP

HidD_GetHidGuid PROC
    jmp qword ptr [g_targets + 40]
HidD_GetHidGuid ENDP

HidD_GetIndexedString PROC
    jmp qword ptr [g_targets + 48]
HidD_GetIndexedString ENDP

HidD_GetInputReport PROC
    jmp qword ptr [g_targets + 56]
HidD_GetInputReport ENDP

HidD_GetManufacturerString PROC
    jmp qword ptr [g_targets + 64]
HidD_GetManufacturerString ENDP

HidD_GetMsGenreDescriptor PROC
    jmp qword ptr [g_targets + 72]
HidD_GetMsGenreDescriptor ENDP

HidD_GetNumInputBuffers PROC
    jmp qword ptr [g_targets + 80]
HidD_GetNumInputBuffers ENDP

HidD_GetPhysicalDescriptor PROC
    jmp qword ptr [g_targets + 88]
HidD_GetPhysicalDescriptor ENDP

HidD_GetPreparsedData PROC
    jmp qword ptr [g_targets + 96]
HidD_GetPreparsedData ENDP

HidD_GetProductString PROC
    jmp qword ptr [g_targets + 104]
HidD_GetProductString ENDP

HidD_GetSerialNumberString PROC
    jmp qword ptr [g_targets + 112]
HidD_GetSerialNumberString ENDP

HidD_Hello PROC
    jmp qword ptr [g_targets + 120]
HidD_Hello ENDP

HidD_SetConfiguration PROC
    jmp qword ptr [g_targets + 128]
HidD_SetConfiguration ENDP

HidD_SetFeature PROC
    jmp qword ptr [g_targets + 136]
HidD_SetFeature ENDP

HidD_SetNumInputBuffers PROC
    jmp qword ptr [g_targets + 144]
HidD_SetNumInputBuffers ENDP

HidD_SetOutputReport PROC
    jmp qword ptr [g_targets + 152]
HidD_SetOutputReport ENDP

HidP_GetButtonArray PROC
    jmp qword ptr [g_targets + 160]
HidP_GetButtonArray ENDP

HidP_GetButtonCaps PROC
    jmp qword ptr [g_targets + 168]
HidP_GetButtonCaps ENDP

HidP_GetCaps PROC
    jmp qword ptr [g_targets + 176]
HidP_GetCaps ENDP

HidP_GetData PROC
    jmp qword ptr [g_targets + 184]
HidP_GetData ENDP

HidP_GetExtendedAttributes PROC
    jmp qword ptr [g_targets + 192]
HidP_GetExtendedAttributes ENDP

HidP_GetLinkCollectionNodes PROC
    jmp qword ptr [g_targets + 200]
HidP_GetLinkCollectionNodes ENDP

HidP_GetScaledUsageValue PROC
    jmp qword ptr [g_targets + 208]
HidP_GetScaledUsageValue ENDP

HidP_GetSpecificButtonCaps PROC
    jmp qword ptr [g_targets + 216]
HidP_GetSpecificButtonCaps ENDP

HidP_GetSpecificValueCaps PROC
    jmp qword ptr [g_targets + 224]
HidP_GetSpecificValueCaps ENDP

HidP_GetUsages PROC
    jmp qword ptr [g_targets + 232]
HidP_GetUsages ENDP

HidP_GetUsagesEx PROC
    jmp qword ptr [g_targets + 240]
HidP_GetUsagesEx ENDP

HidP_GetUsageValue PROC
    jmp qword ptr [g_targets + 248]
HidP_GetUsageValue ENDP

HidP_GetUsageValueArray PROC
    jmp qword ptr [g_targets + 256]
HidP_GetUsageValueArray ENDP

HidP_GetValueCaps PROC
    jmp qword ptr [g_targets + 264]
HidP_GetValueCaps ENDP

HidP_GetVersionInternal PROC
    jmp qword ptr [g_targets + 272]
HidP_GetVersionInternal ENDP

HidP_InitializeReportForID PROC
    jmp qword ptr [g_targets + 280]
HidP_InitializeReportForID ENDP

HidP_MaxDataListLength PROC
    jmp qword ptr [g_targets + 288]
HidP_MaxDataListLength ENDP

HidP_MaxUsageListLength PROC
    jmp qword ptr [g_targets + 296]
HidP_MaxUsageListLength ENDP

HidP_SetButtonArray PROC
    jmp qword ptr [g_targets + 304]
HidP_SetButtonArray ENDP

HidP_SetData PROC
    jmp qword ptr [g_targets + 312]
HidP_SetData ENDP

HidP_SetScaledUsageValue PROC
    jmp qword ptr [g_targets + 320]
HidP_SetScaledUsageValue ENDP

HidP_SetUsages PROC
    jmp qword ptr [g_targets + 328]
HidP_SetUsages ENDP

HidP_SetUsageValue PROC
    jmp qword ptr [g_targets + 336]
HidP_SetUsageValue ENDP

HidP_SetUsageValueArray PROC
    jmp qword ptr [g_targets + 344]
HidP_SetUsageValueArray ENDP

HidP_TranslateUsagesToI8042ScanCodes PROC
    jmp qword ptr [g_targets + 352]
HidP_TranslateUsagesToI8042ScanCodes ENDP

HidP_UnsetUsages PROC
    jmp qword ptr [g_targets + 360]
HidP_UnsetUsages ENDP

HidP_UsageListDifference PROC
    jmp qword ptr [g_targets + 368]
HidP_UsageListDifference ENDP

END
