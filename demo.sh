#!/usr/bin/env bash
#

# Experimente...

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0

DECSEPERATOR=.

# Settings
inverterIP="192.168.30.45"
inverterModBusPort="502"
if [ "$1" = "" ]; then
    debug=0
else 
    debug=1    # 1 debug active
fi

callModBus="tclsh /usr/local/addons/modbus/modbus_interface.tcl $inverterIP $inverterModBusPort 1 03" # fiex on ID 1 & Read

invCommonBlock=40000
invModel103Block=40069
meterCommonBlock=40121
meterModel203Block=40188

## Generic functions to read modbus register

declare -a modBusDataCache  # if filled value are read from here instead of bus -> bulk read, [0] contains offset

function GetBulkValue() {
    local register=$1
    local length=$2

    #echo "Read $register for $length - "
    local val=""
    register=$(($register - ${modBusDataCache[0]} + 1)) # fix offset
    length=$(($register + $length - 1))
    #echo "Start index $register, end index $length - "
    for (( ii=$register ; ii <= $length ; ii++ )); do
        val="$val ${modBusDataCache[ii]}"
    done
    echo $val
}

function ReadBulkData() {
    local register=$1
    local length=$2
    local ret

    local val=$($callModBus $register $length)
    ret=$?
    modBusDataCache=( $register $val )

    if [ $ret -eq 0 ]; then
        return $RETURN_SUCCESS
    else
        return $RETURN_FAILURE
    fi
}

function ClearBulkData() {
    unset modBusDataCache
}

function IsBulkAvailable() {
    if [[ ${modBusDataCache[@]:+${modBusDataCache[@]}} ]]; then
        return $RETURN_SUCCESS
    else
        return $RETURN_FAILURE
    fi
}

function GetModBusValue() {
    local register=$1
    local length=$2
    local ret
    local val

    if IsBulkAvailable; then
        val=$(GetBulkValue $register $length)
        ret=$RETURN_SUCCESS
    else 
        val=$($callModBus $register $length)
        ret=$?
    fi

    if [ $ret -eq 0 ]; then
        echo "$val"
        return $RETURN_SUCCESS
    else
        return $RETURN_FAILURE
    fi
}

function GetUInt16Register() {
    local register=$1

    GetModBusValue $register 1
    return $?
}

function GetUInt32Register() {
    local register=$1

    local vals=( $(GetModBusValue $register 2) )
    local ret=$?

    if [ "${vals[0]}" = "" ]; then
        vals[0]=0
    fi
    if [ "${vals[1]}" = "" ]; then
        vals[1]=0
    fi
    echo $((${vals[0]} * 65536 + ${vals[1]}))

    return $ret
}

# thanks to https://stackoverflow.com/a/12855787
chr() {
  printf \\$(printf '%03o' $1)
}

function GetStringRegister() {
    local register=$1
    local length=$2

    local vals=( $(GetModBusValue $register $length) )
    local ret=$?

    local output=""
    local val1
    local val2

    for ii in ${!vals[@]}; do
        val1=${vals[ii]}
        if (( $val1 > 0 )); then
            val2=$(($val1 / 256))
            if (( val2 > 0 )); then
                output=$output$(chr $val2)
            fi
            val2=$(($val1 % 256))
            if (( val2 > 0 )); then
                output=$output$(chr $val2)
            fi
        fi
    done

    echo $output
    return $ret
}

function GetScaleFactor() {
    local register=$1
    
    local val=$(GetModBusValue $register 1)
    local ret=$?
    echo $val
    return $ret
}

function GetScaledUInt32FloatValue() {
    local register=$1
    local scale=$2

    local val=$(GetUInt32Register $register)
    local ret=$?

    # string solution - scale 0 / -1 / -2 / ..
    if [ "$scale" = "" ]; then
        scale=0
    fi
    if [ $scale -lt 0 -a $val -gt 0 ]; then
        local valLen=${#val}
        local sepPos=$(($valLen + $scale))
        if (( sepPos -eq 0 )); then 
            echo "0$DECSEPERATOR${val:$sepPos}"
        else
            echo "${val:0:$sepPos}$DECSEPERATOR${val:$sepPos}"
        fi
    else
        echo $val
    fi

    return $ret
}

function GetScaledUInt16FloatValue() {
    local register=$1
    local scale=$2

    local val=$(GetUInt16Register $register)
    local ret=$?

    if [ "$scale" = "" ]; then
        scale=0
    fi
    if [ $scale -lt  0 -a $val -gt 0 ]; then
        local valLen=${#val}
        local sepPos=$(($valLen + $scale))
        if (( sepPos == 0 )); then 
            echo "0$DECSEPERATOR${val:$sepPos}"
        else
            echo "${val:0:$sepPos}$DECSEPERATOR${val:$sepPos}"
        fi
    else
        echo $val
    fi

    return $ret
}

function GetInverterOperatingState() {
    local register=$1

    local val=$(GetUInt16Register $register)
    local ret=$?

    case $val in 
        1 ) echo "Off";;
        2 ) echo "Sleeping";;
        3 ) echo "Starting";;
        4 ) echo "MPPT";;
        5 ) echo "Throttled";;
        6 ) echo "Shutting down";;
        7 ) echo "Fault";;
        9 ) echo "Standby";;
        * ) echo "Unknown operating state no $val";;
    esac
    return $ret
}

function GetInverterErrorState() {
    local register=$1

    local val=$(GetUInt16Register $register)
    local ret=$?

    case $val in
        -1 ) echo "None";;   # ??
        0  ) echo "Ground fault";;
        1  ) echo "DC over voltage";;
        2  ) echo "AC disconnect open";;
        3  ) echo "DC disconnect open";;
        4  ) echo "Grid shutdown";;
        5  ) echo "Cabinet open";;
        6  ) echo "Manual shutdown";;
        7  ) echo "Over temperature";;
        8  ) echo "Frequency above limit";;
        9  ) echo "Frequency under limit";;
        10 ) echo "AC Voltage above limit";;
        11 ) echo "AC Voltage under limit";;
        12 ) echo "Blown String fuse on input";;
        13 ) echo "Under temperature";;
        14 ) echo "Generic Memory or Communication error (internal)";;
        15 ) echo "Hardware test failure";;
        *  ) echo "Unknown error state no $val";;
    esac

    return $ret
}

function GetMeterErrorState() {
    local register=$1

    local val=$(GetUInt16Register $register)
    local ret=$?

    case $val in
        0|""  ) echo "None";;
        2  ) echo "Power Failure";;
        3  ) echo "Under Voltage";;
        4  ) echo "Low PF";;
        5  ) echo "Over Current";;
        6  ) echo "Over Voltage";;
        7  ) echo "Missing Sensor";;
        *  ) echo "Unknown error state no $val";;
    esac

    return $ret
}

## SolarEdge specific functions

function ReadInverterCommonData() {
    ReadBulkData $invCommonBlock 66
    # inverter does not follow SunSpec ID 1...
    inverterData_ID=$(GetStringRegister $(($invCommonBlock + 0)) 2)
    inverterData_DID=$(GetUInt16Register $(($invCommonBlock + 2)))
    inverterData_L=$(GetUInt16Register $(($invCommonBlock + 3)))
    inverterData_Mn=$(GetStringRegister $(($invCommonBlock + 4)) 16)
    inverterData_Md=$(GetStringRegister $(($invCommonBlock + 19)) 16)
    inverterData_Opt=$(GetStringRegister $(($invCommonBlock + 34)) 8)
    inverterData_Vr=$(GetStringRegister $(($invCommonBlock + 42)) 8)
    inverterData_SN=$(GetStringRegister $(($invCommonBlock + 50)) 16)
    inverterData_DA=$(GetUInt16Register $(($invCommonBlock + 66)))
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
    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadMeterCommonData() {
    ReadBulkData $meterCommonBlock 66
    meterData_ID=$(GetUInt16Register $(($meterCommonBlock + 0)))
    meterData_L=$(GetUInt16Register $(($meterCommonBlock + 1)))
    meterData_Mn=$(GetStringRegister $(($meterCommonBlock + 2)) 16)
    meterData_Md=$(GetStringRegister $(($meterCommonBlock + 18)) 16)
    meterData_Opt=$(GetStringRegister $(($meterCommonBlock + 34)) 8)
    meterData_Vr=$(GetStringRegister $(($meterCommonBlock + 42)) 8)
    meterData_SN=$(GetStringRegister $(($meterCommonBlock + 50)) 16)
    meterData_DA=$(GetUInt16Register $(($meterCommonBlock + 66)))
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
    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadInverterGeneralStatus() {
    local val
    local scale

    # Check if we're on the right ID..
    val=$(GetUInt16Register $((invModel103Block + 0)))
    if (( val == 103 )); then
        if ((debug)); then 
            echo "ID     : $val (matched)"
        fi
    else
        echo "ID     : $val (UNMATCHED - expected 103)"
        return $RETURN_FAILURE
    fi
    val=$(GetUInt16Register $((invModel103Block + 1)))
    if (( val == 50 )); then
        if ((debug)); then 
            echo "L      : $val (matched)"
        fi
    else
        echo "L      : $val (UNMATCHED - expected 50)"
        return $RETURN_FAILURE
    fi

    scale=$(GetScaleFactor $((invModel103Block + 37)))
    #inverterData_TmpCab="$(GetScaledUInt16FloatValue $((invModel103Block + 33)) $scale) °C"   # mandatory but obviously not used..
    inverterData_TmpSnk="$(GetScaledUInt16FloatValue $((invModel103Block + 34)) $scale) °C"    # optional but filled
    #inverterData_TmpTrns="$(GetScaledUInt16FloatValue $((invModel103Block + 35)) $scale) °C"  # seems unused
    #inverterData_TmpOt="$(GetScaledUInt16FloatValue $((invModel103Block + 36)) $scale) °C"    # seems unused

    inverterData_St="$(GetInverterOperatingState $((invModel103Block + 38)))"
    inverterData_StVnd="$(GetUInt16Register $((invModel103Block + 39)))"
    inverterData_Evt1="$(GetInverterErrorState $((invModel103Block + 40)))" 

    if (( debug )); then
        echo "TmpSnk : $inverterData_TmpSnk"
        echo "St     : $inverterData_St"
        echo "StVnd  : $inverterData_StVnd"
        echo "Evt1   : $inverterData_Evt1"
    fi
}

function ReadInverterBaseData() {
    local val
    local scale

    scale=$(GetScaleFactor $((invModel103Block + 6)))
    inverterData_A="$(GetScaledUInt16FloatValue $((invModel103Block + 2)) $scale) A"
    inverterData_AphA="$(GetScaledUInt16FloatValue $((invModel103Block + 3)) $scale) A"
    inverterData_AphB="$(GetScaledUInt16FloatValue $((invModel103Block + 4)) $scale) A"
    inverterData_AphC="$(GetScaledUInt16FloatValue $((invModel103Block + 5)) $scale) A"

    scale=$(GetScaleFactor $((invModel103Block + 15)))
    inverterData_W="$(GetScaledUInt16FloatValue $((invModel103Block + 14)) $scale) W"

    scale=$(GetScaleFactor $((invModel103Block + 26)))
    inverterData_WH="$(GetScaledUInt32FloatValue $((invModel103Block + 24)) $scale) Wh"

    scale=$(GetScaleFactor $((invModel103Block + 28)))
    inverterData_DCA="$(GetScaledUInt16FloatValue $((invModel103Block + 27)) $scale) A"

    scale=$(GetScaleFactor $((invModel103Block + 30)))
    inverterData_DCV="$(GetScaledUInt16FloatValue $((invModel103Block + 29)) $scale) V"

    scale=$(GetScaleFactor $((invModel103Block + 32)))
    inverterData_DCW="$(GetScaledUInt16FloatValue $((invModel103Block + 31)) $scale) W"

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

    return $RETURN_SUCCESS
}

function ReadInverterFullData() {
    local val
    local scale

    scale=$(GetScaleFactor $((invModel103Block + 6)))
    inverterData_A="$(GetScaledUInt16FloatValue $((invModel103Block + 2)) $scale) A"
    inverterData_AphA="$(GetScaledUInt16FloatValue $((invModel103Block + 3)) $scale) A"
    inverterData_AphB="$(GetScaledUInt16FloatValue $((invModel103Block + 4)) $scale) A"
    inverterData_AphC="$(GetScaledUInt16FloatValue $((invModel103Block + 5)) $scale) A"

    scale=$(GetScaleFactor $((invModel103Block + 13)))
    inverterData_PPVphAB="$(GetScaledUInt16FloatValue $((invModel103Block + 7)) $scale) V"
    inverterData_PPVphBC="$(GetScaledUInt16FloatValue $((invModel103Block + 8)) $scale) V"
    inverterData_PPVphCA="$(GetScaledUInt16FloatValue $((invModel103Block + 9)) $scale) V"
    inverterData_PPVphA="$(GetScaledUInt16FloatValue $((invModel103Block + 10)) $scale) V"
    inverterData_PPVphB="$(GetScaledUInt16FloatValue $((invModel103Block + 11)) $scale) V"
    inverterData_PPVphC="$(GetScaledUInt16FloatValue $((invModel103Block + 12)) $scale) V"

    scale=$(GetScaleFactor $((invModel103Block + 15)))
    inverterData_W="$(GetScaledUInt16FloatValue $((invModel103Block + 14)) $scale) W"

    scale=$(GetScaleFactor $((invModel103Block + 17)))
    inverterData_Hz="$(GetScaledUInt16FloatValue $((invModel103Block + 16)) $scale) Hz"

    scale=$(GetScaleFactor $((invModel103Block + 19)))
    inverterData_VA="$(GetScaledUInt16FloatValue $((invModel103Block + 18)) $scale) VA"

    scale=$(GetScaleFactor $((invModel103Block + 21)))
    inverterData_VAr="$(GetScaledUInt16FloatValue $((invModel103Block + 20)) $scale) var"

    scale=$(GetScaleFactor $((invModel103Block + 23)))
    inverterData_PF="$(GetScaledUInt16FloatValue $((invModel103Block + 22)) $scale) %"

    scale=$(GetScaleFactor $((invModel103Block + 26)))
    inverterData_WH="$(GetScaledUInt32FloatValue $((invModel103Block + 24)) $scale) Wh"

    scale=$(GetScaleFactor $((invModel103Block + 28)))
    inverterData_DCA="$(GetScaledUInt16FloatValue $((invModel103Block + 27)) $scale) A"

    scale=$(GetScaleFactor $((invModel103Block + 30)))
    inverterData_DCV="$(GetScaledUInt16FloatValue $((invModel103Block + 29)) $scale) V"

    scale=$(GetScaleFactor $((invModel103Block + 32)))
    inverterData_DCW="$(GetScaledUInt16FloatValue $((invModel103Block + 31)) $scale) W"

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

    return $RETURN_SUCCESS
}

function ReadMeterBaseData() {
    local val
    local scale

    scale=$(GetScaleFactor $((meterModel203Block + 6)))
    meterData_A="$(GetScaledUInt16FloatValue $((meterModel203Block + 2)) $scale) A"

    scale=$(GetScaleFactor $((meterModel203Block + 15)))
    meterData_PhV="$(GetScaledUInt16FloatValue $((meterModel203Block + 7)) $scale) V"

    scale=$(GetScaleFactor $((meterModel203Block + 22)))
    meterData_W="$(GetScaledUInt16FloatValue $((meterModel203Block + 18)) $scale) W"
    meterData_WphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 19)) $scale) W"
    meterData_WphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 20)) $scale) W"
    meterData_WphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 21)) $scale) W"

    scale=$(GetScaleFactor $((meterModel203Block + 54)))
    meterData_TotWhExp="$(GetScaledUInt32FloatValue $((meterModel203Block + 38)) $scale) Wh"
    meterData_TotWhExpPhA="$(GetScaledUInt32FloatValue $((meterModel203Block + 40)) $scale) Wh"
    meterData_TotWhExpPhB="$(GetScaledUInt32FloatValue $((meterModel203Block + 42)) $scale) Wh"
    meterData_TotWhExpPnC="$(GetScaledUInt32FloatValue $((meterModel203Block + 44)) $scale) Wh"
    meterData_TotWhImp="$(GetScaledUInt32FloatValue $((meterModel203Block + 46)) $scale) Wh"
    meterData_TotWhImpPhA="$(GetScaledUInt32FloatValue $((meterModel203Block + 48)) $scale) Wh"
    meterData_TotWhImpPhB="$(GetScaledUInt32FloatValue $((meterModel203Block + 50)) $scale) Wh"
    meterData_TotWhImpPnC="$(GetScaledUInt32FloatValue $((meterModel203Block + 52)) $scale) Wh"

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

function ReadMeterGeneralStatus() {
    local val
    local scale

    # Check if we're on the right ID..
    val=$(GetUInt16Register $((meterModel203Block + 0)))
    if (( val == 203 )); then
        if ((debug)); then
            echo "ID           : $val (matched)"
        fi
    else
        echo "ID           : $val (UNMATCHED - expected 103)"
        return $RETURN_FAILURE
    fi
    val=$(GetUInt16Register $((meterModel203Block + 1)))
    if (( val == 105 )); then
        if ((debug)); then
            echo "L            : $val (matched)"
        fi
    else
        echo "L            : $val (UNMATCHED - expected 50)"
        return $RETURN_FAILURE
    fi

    meterData_Evt="$(GetMeterErrorState $((meterModel203Block + 105)))"

    if (( debug )); then
        echo "Evt          : $meterData_Evt"
    fi
}

function ReadMeterFullData() {
    local val
    local scale

    scale=$(GetScaleFactor $((meterModel203Block + 6)))
    meterData_A="$(GetScaledUInt16FloatValue $((meterModel203Block + 2)) $scale) A"
    meterData_AphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 3)) $scale) A"
    meterData_AphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 4)) $scale) A"
    meterData_AphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 5)) $scale) A"

    scale=$(GetScaleFactor $((meterModel203Block + 15)))
    meterData_PhV="$(GetScaledUInt16FloatValue $((meterModel203Block + 7)) $scale) V"
    meterData_PhVphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 8)) $scale) V"
    meterData_PhVphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 9)) $scale) V"
    meterData_PVphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 10)) $scale) V"
    meterData_PPV="$(GetScaledUInt16FloatValue $((meterModel203Block + 11)) $scale) V"
    meterData_PhVphAB="$(GetScaledUInt16FloatValue $((meterModel203Block + 12)) $scale) V"
    meterData_PhVphBC="$(GetScaledUInt16FloatValue $((meterModel203Block + 13)) $scale) V"
    meterData_PhVphCA="$(GetScaledUInt16FloatValue $((meterModel203Block + 14)) $scale) V"

    scale=$(GetScaleFactor $((meterModel203Block + 17)))
    meterData_Hz="$(GetScaledUInt16FloatValue $((meterModel203Block + 16)) $scale) Hz"

    scale=$(GetScaleFactor $((meterModel203Block + 22)))
    meterData_W="$(GetScaledUInt16FloatValue $((meterModel203Block + 18)) $scale) W"
    meterData_WphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 19)) $scale) W"
    meterData_WphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 20)) $scale) W"
    meterData_WphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 21)) $scale) W"

    scale=$(GetScaleFactor $((meterModel203Block + 27)))
    meterData_VA="$(GetScaledUInt16FloatValue $((meterModel203Block + 23)) $scale) VA"
    meterData_VAphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 24)) $scale) VA"
    meterData_VAphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 25)) $scale) VA"
    meterData_VAphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 26)) $scale) VA"

    scale=$(GetScaleFactor $((meterModel203Block + 32)))
    meterData_VAR="$(GetScaledUInt16FloatValue $((meterModel203Block + 28)) $scale) var"
    meterData_VARphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 29)) $scale) var"
    meterData_VARphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 30)) $scale) var"
    meterData_VARphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 31)) $scale) var"

    scale=$(GetScaleFactor $((meterModel203Block + 37)))
    meterData_PF="$(GetScaledUInt16FloatValue $((meterModel203Block + 33)) $scale) %"
    meterData_PFphA="$(GetScaledUInt16FloatValue $((meterModel203Block + 34)) $scale) %"
    meterData_PFphB="$(GetScaledUInt16FloatValue $((meterModel203Block + 35)) $scale) %"
    meterData_PFphC="$(GetScaledUInt16FloatValue $((meterModel203Block + 36)) $scale) %"

    scale=$(GetScaleFactor $((meterModel203Block + 54)))
    meterData_TotWhExp="$(GetScaledUInt32FloatValue $((meterModel203Block + 38)) $scale) Wh"
    meterData_TotWhExpPhA="$(GetScaledUInt32FloatValue $((meterModel203Block + 40)) $scale) Wh"
    meterData_TotWhExpPhB="$(GetScaledUInt32FloatValue $((meterModel203Block + 42)) $scale) Wh"
    meterData_TotWhExpPnC="$(GetScaledUInt32FloatValue $((meterModel203Block + 44)) $scale) Wh"
    meterData_TotWhImp="$(GetScaledUInt32FloatValue $((meterModel203Block + 46)) $scale) Wh"
    meterData_TotWhImpPhA="$(GetScaledUInt32FloatValue $((meterModel203Block + 48)) $scale) Wh"
    meterData_TotWhImpPhB="$(GetScaledUInt32FloatValue $((meterModel203Block + 50)) $scale) Wh"
    meterData_TotWhImpPnC="$(GetScaledUInt32FloatValue $((meterModel203Block + 52)) $scale) Wh"

    # feels unsed in WattNode SE-WND-3Y-400-MB
    # scale=$(GetScaleFactor $((meterModel203Block + 71)))
    # echo "TotVAhExp    : $(GetScaledUInt32FloatValue $((meterModel203Block + 55)) $scale) VAh"
    # echo "TotVAhExpPhA : $(GetScaledUInt32FloatValue $((meterModel203Block + 57)) $scale) VAh"
    # echo "TotVAhExpPhB : $(GetScaledUInt32FloatValue $((meterModel203Block + 59)) $scale) VAh"
    # echo "TotVAhExpPnC : $(GetScaledUInt32FloatValue $((meterModel203Block + 61)) $scale) VAh"
    # echo "TotVAhImp    : $(GetScaledUInt32FloatValue $((meterModel203Block + 63)) $scale) VAh"
    # echo "TotVAhImpPhA : $(GetScaledUInt32FloatValue $((meterModel203Block + 65)) $scale) VAh"
    # echo "TotVAhImpPhB : $(GetScaledUInt32FloatValue $((meterModel203Block + 67)) $scale) VAh"
    # echo "TotVAhImpPhC : $(GetScaledUInt32FloatValue $((meterModel203Block + 69)) $scale) VAh"

    # scale=$(GetScaleFactor $((meterModel203Block + 104)))
    # echo "TotVArhImpQ1   : $(GetScaledUInt32FloatValue $((meterModel203Block + 72)) $scale) varh"
    # echo "TotVArhImpQ1PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 74)) $scale) varh"
    # echo "TotVArhImpQ1PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 76)) $scale) varh"
    # echo "TotVArhImpQ1PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 78)) $scale) varh"
    # echo "TotVArhImpQ2   : $(GetScaledUInt32FloatValue $((meterModel203Block + 80)) $scale) varh"
    # echo "TotVArhImpQ2PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 82)) $scale) varh"
    # echo "TotVArhImpQ2PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 84)) $scale) varh"
    # echo "TotVArhImpQ2PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 86)) $scale) varh"
    # echo "TotVArhExpQ3   : $(GetScaledUInt32FloatValue $((meterModel203Block + 88)) $scale) varh"
    # echo "TotVArhExpQ3PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 90)) $scale) varh"
    # echo "TotVArhExpQ3PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 92)) $scale) varh"
    # echo "TotVArhExpQ3PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 94)) $scale) varh"
    # echo "TotVArhExpQ4   : $(GetScaledUInt32FloatValue $((meterModel203Block + 96)) $scale) varh"
    # echo "TotVArhExpQ4PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 98)) $scale) varh"
    # echo "TotVArhExpQ4PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 100)) $scale) varh"
    # echo "TotVArhExpQ4PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 102)) $scale) varh"

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

#ReadInverterCommonData
#ReadMeterCommonData
echo "Start Inverter"
ReadBulkData $invModel103Block 50
ReadInverterBaseData
#ReadInverterGeneralStatus
#ReadInverterFullData
ClearBulkData
echo "Start Meter"
ReadBulkData $meterModel203Block 50
ReadMeterBaseData
#ReadMeterGeneralStatus
#ReadMeterFullData
ClearBulkData
