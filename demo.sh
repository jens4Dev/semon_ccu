#!/usr/bin/env bash
#

# Experimente...

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0

DECSEPERATOR=.

# Settings
SE_INVERTER_IP="192.168.30.45"
SE_INVERTER_MODBUS_PORT="502"

if [ "$1" = "" ]; then
    debug=0
else 
    debug=1    # 1 debug active
fi

source "pvread_funclib.sh"

function PrintInverterCommonData() {
    if (( debug )); then
        echo "ID : $inverterData_ID"
        echo "DID: $inverterData_DID"
        echo "L  : $inverterData_L"
        echo "Mn : $inverterData_Mn"
        echo "Md : $inverterData_Md"
        echo "Opt: $inverterData_Opt"
        echo "Vr : $inverterData_Vr"
        echo "SN : $inverterData_SN"
        echo "DA : $inverterData_DA"
    fi
}

function PrintInverterGeneralStatus() {
    if (( debug )); then
        echo "ID     : $inverterData_ID"
        echo "L      : $inverterData_L"
        echo "TmpSnk : $inverterData_TmpSnk"
        echo "St     : $inverterData_St"
        echo "StVnd  : $inverterData_StVnd"
        echo "Evt1   : $inverterData_Evt1"
    fi
}

function PrintInverterBaseData() {
    if (( debug )); then
        echo "A      : $inverterData_A"
        echo "AphA   : $inverterData_AphA"
        echo "AphB   : $inverterData_AphB"
        echo "AphC   : $inverterData_AphC"
        echo "W      : $inverterData_W"
        echo "WH     : $inverterData_WH"
        echo "DCA    : $inverterData_DCA"
        echo "DCV    : $inverterData_DCV"
        echo "DCW    : $inverterData_DCW"
    fi
}

function PrintInverterFullData() {
    if (( debug )); then
        echo "A      : $inverterData_A"
        echo "AphA   : $inverterData_AphA"
        echo "AphB   : $inverterData_AphB"
        echo "AphC   : $inverterData_AphC"
        echo "PPVphAB: $inverterData_PPVphAB"
        echo "PPVphBC: $inverterData_PPVphBC"
        echo "PPVphCA: $inverterData_PPVphCA"
        echo "PPVphA : $inverterData_PPVphA"
        echo "PPVphB : $inverterData_PPVphB"
        echo "PPVphC : $inverterData_PPVphC"
        echo "W      : $inverterData_W"
        echo "Hz     : $inverterData_Hz"
        echo "VA     : $inverterData_VA"
        echo "VAr    : $inverterData_VAr"
        echo "PF     : $inverterData_PF"
        echo "WH     : $inverterData_WH"
        echo "DCA    : $inverterData_DCA"
        echo "DCV    : $inverterData_DCV"
        echo "DCW    : $inverterData_DCW"
    fi
}

function PrintMeterCommonData() {
    if (( debug )); then
        echo "ID : $meterData_ID"
        echo "L  : $meterData_L"
        echo "Mn : $meterData_Mn"
        echo "Md : $meterData_Md"
        echo "Opt: $meterData_Opt"
        echo "Vr : $meterData_Vr"
        echo "SN : $meterData_SN"
        echo "DA : $meterData_DA"
    fi
}

function PrintMeterGeneralStatus() {
    if (( debug )); then
        echo "ID           : $meterData_ID"
        echo "L            : $meterData_L"
        echo "Evt          : $meterData_Evt"
    fi
}

function PrintMeterBaseData() {
    if (( debug )); then
        echo "A            : $meterData_A"
        echo "PhV          : $meterData_PhV"
        echo "W            : $meterData_W"
        echo "WphA         : $meterData_WphA"
        echo "WphB         : $meterData_WphB"
        echo "WphC         : $meterData_WphC"
        echo "TotWhExp     : $meterData_TotWhExp"
        echo "TotWhExpPhA  : $meterData_TotWhExpPhA"
        echo "TotWhExpPhB  : $meterData_TotWhExpPhB"
        echo "TotWhExpPnC  : $meterData_TotWhExpPnC"
        echo "TotWhImp     : $meterData_TotWhImp"
        echo "TotWhImpPhA  : $meterData_TotWhImpPhA"
        echo "TotWhImpPhB  : $meterData_TotWhImpPhB"
        echo "TotWhImpPnC  : $meterData_TotWhImpPnC"
    fi

}

function PrintMeterFullData() {
        if (( debug )); then
        echo "A            : $meterData_A"
        echo "AphA         : $meterData_AphA"
        echo "AphB         : $meterData_AphB"
        echo "AphC         : $meterData_AphC"
        echo "PhV          : $meterData_PhV"
        echo "PhVphA       : $meterData_PhVphA"
        echo "PhVphB       : $meterData_PhVphB"
        echo "PVphC        : $meterData_PVphC"
        echo "PPV          : $meterData_PPV"
        echo "PhVphAB      : $meterData_PhVphAB"
        echo "PhVphBC      : $meterData_PhVphBC"
        echo "PhVphCA      : $meterData_PhVphCA"
        echo "Hz           : $meterData_Hz"
        echo "W            : $meterData_W"
        echo "WphA         : $meterData_WphA"
        echo "WphB         : $meterData_WphB"
        echo "WphC         : $meterData_WphC"
        echo "VA           : $meterData_VA"
        echo "VAphA        : $meterData_VAphA"
        echo "VAphB        : $meterData_VAphB"
        echo "VAphC        : $meterData_VAphC"
        echo "VAR          : $meterData_VAR"
        echo "VARphA       : $meterData_VARphA"
        echo "VARphB       : $meterData_VARphB"
        echo "VARphC       : $meterData_VARphC"
        echo "PF           : $meterData_PF"
        echo "PFphA        : $meterData_PFphA"
        echo "PFphB        : $meterData_PFphB"
        echo "PFphC        : $meterData_PFphC"
        echo "TotWhExp     : $meterData_TotWhExp"
        echo "TotWhExpPhA  : $meterData_TotWhExpPhA"
        echo "TotWhExpPhB  : $meterData_TotWhExpPhB"
        echo "TotWhExpPnC  : $meterData_TotWhExpPnC"
        echo "TotWhImp     : $meterData_TotWhImp"
        echo "TotWhImpPhA  : $meterData_TotWhImpPhA"
        echo "TotWhImpPhB  : $meterData_TotWhImpPhB"
        echo "TotWhImpPnC  : $meterData_TotWhImpPnC"
    fi
}

# IsBulkAvailable
# echo "1 = $?"
# modBusDataCache=(256)
# IsBulkAvailable
# echo "0 = $?"
# modBusDataCache=(256 3)
# unset modBusDataCache[0]
# IsBulkAvailable
# echo "0 = $?"
# unset modBusDataCache[0]
# IsBulkAvailable
# echo "1/0 = $?"
# ClearBulkData
# IsBulkAvailable
# echo "1 = $?"

# ReadBulkData $invModel103Block 50
# IsBulkAvailable
# echo "0 = $?"
# echo "modBusDataCache: ${modBusDataCache[*]}"
# echo "# in modBusDataCache ${#modBusDataCache[*]}"
# echo $(GetBulkValue $((invModel103Block + 0)) 1)
# echo $(GetBulkValue $((invModel103Block + 2)) 6)
# echo $(GetBulkValue $((invModel103Block + 6)) 54)
# echo $(GetModBusValue $((invModel103Block + 0)) 1)
# echo $(GetModBusValue $((invModel103Block + 2)) 6)
# echo $(GetModBusValue $((invModel103Block + 6)) 54)
# ClearBulkData

if [ "$1" = "FULL" ]; then
    ReadInverterCommonData
    PrintInverterCommonData
    ReadMeterCommonData
    PrintMeterCommonData
    echo ""
    ReadBulkDataInverter
    ReadInverterGeneralStatus
    PrintInverterGeneralStatus
    ReadInverterFullData
    PrintInverterFullData
    ClearBulkData
    echo ""
    ReadBulkDataMeter
    ReadMeterGeneralStatus
    PrintMeterGeneralStatus
    ReadMeterFullData
    PrintMeterFullData
    ClearBulkData
else
    echo "Start Inverter"
    ReadBulkDataInverter
    ReadInverterBaseData
    PrintInverterBaseData
    ClearBulkData
    echo "Start Meter"
    ReadBulkDataMeter
    ReadMeterBaseData
    PrintMeterBaseData
    ClearBulkData
fi