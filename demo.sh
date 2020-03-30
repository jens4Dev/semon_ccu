#!/bin/bash
#

# Experimente...

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0

DECSEPERATOR=.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/bin"

# Settings
SE_INVERTER_IP="192.168.30.45"
SE_INVERTER_MODBUS_PORT="502"

if [ "$1" = "" ]; then
    debug=0
else 
    debug=1    # 1 debug active
fi

source "bin/pvread_funclib.sh"

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
        echo "TmpSnk : $inverterData_TmpSnk__C °C"
        echo "St     : $inverterData_St"
        echo "StVnd  : $inverterData_StVnd"
        echo "Evt1   : $inverterData_Evt1"
    fi
}

function PrintInverterBaseData() {
    if (( debug )); then
        echo "A      : $inverterData_A__A"
        echo "AphA   : $inverterData_AphA__A"
        echo "AphB   : $inverterData_AphB__A"
        echo "AphC   : $inverterData_AphC__A"
        echo "W      : $inverterData_W__W"
        echo "WH     : $inverterData_WH__WH"
        echo "DCA    : $inverterData_DCA__A"
        echo "DCV    : $inverterData_DCV__V"
        echo "DCW    : $inverterData_DCW__W"
    fi
}

function PrintInverterFullData() {
    if (( debug )); then
        echo "A      : $inverterData_A__A"
        echo "AphA   : $inverterData_AphA__A"
        echo "AphB   : $inverterData_AphB__A"
        echo "AphC   : $inverterData_AphC__A"
        echo "PPVphAB: $inverterData_PPVphAB__V"
        echo "PPVphBC: $inverterData_PPVphBC__V"
        echo "PPVphCA: $inverterData_PPVphCA__V"
        echo "PPVphA : $inverterData_PPVphA__V"
        echo "PPVphB : $inverterData_PPVphB__V"
        echo "PPVphC : $inverterData_PPVphC__V"
        echo "W      : $inverterData_W__W"
        echo "Hz     : $inverterData_Hz__Hz"
        echo "VA     : $inverterData_VA__VA"
        echo "VAr    : $inverterData_VAr__var"
        echo "PF     : $inverterData_PF__perct"
        echo "WH     : $inverterData_WH__Wh"
        echo "DCA    : $inverterData_DCA__A"
        echo "DCV    : $inverterData_DCV__V"
        echo "DCW    : $inverterData_DCW__W"
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
        echo "A            : $meterData_A__A"
        echo "PhV          : $meterData_PhV__V"
        echo "W            : $meterData_W__W"
        echo "WphA         : $meterData_WphA__W"
        echo "WphB         : $meterData_WphB__W"
        echo "WphC         : $meterData_WphC__W"
        echo "TotWhExp     : $meterData_TotWhExp__Wh"
        echo "TotWhExpPhA  : $meterData_TotWhExpPhA__Wh"
        echo "TotWhExpPhB  : $meterData_TotWhExpPhB__Wh"
        echo "TotWhExpPnC  : $meterData_TotWhExpPnC__Wh"
        echo "TotWhImp     : $meterData_TotWhImp__Wh"
        echo "TotWhImpPhA  : $meterData_TotWhImpPhA__Wh"
        echo "TotWhImpPhB  : $meterData_TotWhImpPhB__Wh"
        echo "TotWhImpPnC  : $meterData_TotWhImpPnC__Wh"
    fi

}

function PrintMeterFullData() {
        if (( debug )); then
        echo "A            : $meterData_A__A"
        echo "AphA         : $meterData_AphA__A"
        echo "AphB         : $meterData_AphB__A"
        echo "AphC         : $meterData_AphC__A"
        echo "PhV          : $meterData_PhV__V"
        echo "PhVphA       : $meterData_PhVphA__V"
        echo "PhVphB       : $meterData_PhVphB__V"
        echo "PVphC        : $meterData_PVphC__V"
        echo "PPV          : $meterData_PPV__V"
        echo "PhVphAB      : $meterData_PhVphAB__V"
        echo "PhVphBC      : $meterData_PhVphBC__V"
        echo "PhVphCA      : $meterData_PhVphCA__V"
        echo "Hz           : $meterData_Hz__Hz"
        echo "W            : $meterData_W__W"
        echo "WphA         : $meterData_WphA__W"
        echo "WphB         : $meterData_WphB__W"
        echo "WphC         : $meterData_WphC__W"
        echo "VA           : $meterData_VA__VA"
        echo "VAphA        : $meterData_VAphA__VA"
        echo "VAphB        : $meterData_VAphB__VA"
        echo "VAphC        : $meterData_VAphC__VA"
        echo "VAR          : $meterData_VAR__var"
        echo "VARphA       : $meterData_VARphA__var"
        echo "VARphB       : $meterData_VARphB__var"
        echo "VARphC       : $meterData_VARphC__var"
        echo "PF           : $meterData_PF__perct"
        echo "PFphA        : $meterData_PFphA__perct"
        echo "PFphB        : $meterData_PFphB__perct"
        echo "PFphC        : $meterData_PFphC__perct"
        echo "TotWhExp     : $meterData_TotWhExp__Wh"
        echo "TotWhExpPhA  : $meterData_TotWhExpPhA__Wh"
        echo "TotWhExpPhB  : $meterData_TotWhExpPhB__Wh"
        echo "TotWhExpPnC  : $meterData_TotWhExpPnC__Wh"
        echo "TotWhImp     : $meterData_TotWhImp__Wh"
        echo "TotWhImpPhA  : $meterData_TotWhImpPhA__Wh"
        echo "TotWhImpPhB  : $meterData_TotWhImpPhB__Wh"
        echo "TotWhImpPnC  : $meterData_TotWhImpPnC__Wh"
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

GetUInt16Register $invCommonBlock 
GetUInt16Register $((invCommonBlock + 1))
GetUInt32Register $invCommonBlock
GetStringRegister $(($invCommonBlock + 0)) 2
GetUInt16Register $(($invCommonBlock + 2))
GetUInt16Register $(($invCommonBlock + 3))
GetStringRegister $(($invCommonBlock + 4)) 16
GetStringRegister $(($invCommonBlock + 19)) 16


GetUInt16Register $((invModel103Block + 0))
GetUInt16Register $((invModel103Block + 1))
scale=$(GetScaleFactor $((invModel103Block + 37)))
GetScaledUInt16FloatValue $((invModel103Block + 34)) $scale
   #inverterData_TmpTrns__C="$(GetScaledUInt16FloatValue $((invModel103Block + 35)) $scale)"  # seems unused
    #inverterData_TmpOt__C="$(GetScaledUInt16FloatValue $((invModel103Block + 36)) $scale)"    # seems unused

GetInverterOperatingState $((invModel103Block + 38))
GetUInt16Register $((invModel103Block + 39))
GetInverterErrorState $((invModel103Block + 40))
scale=$(GetScaleFactor $((invModel103Block + 26)))
GetScaledUInt32FloatValue $((invModel103Block + 24)) $scale
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