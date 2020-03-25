#!/usr/bin/env bash
#

LC_ALL=C; export LC_ALL
: 'trivial cases first, yet parseable for historic shells'
case $BASH_VERSION in *.*) { echo "bash $BASH_VERSION";};;esac

# Experimente...

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0

DECSEPERATOR=.

# Settings
inverterIP="192.168.30.45"
inverterModBusPort="502"

callModBus="tclsh /usr/local/addons/modbus/modbus_interface.tcl $inverterIP $inverterModBusPort 1 03" # fiex on ID 1 & Read

invCommonBlock=40000
invModel103Block=40069
meterCommonBlock=40121
meterModel203Block=40188

## Generic functions to read modbus register
declare -a dataBlock # if filled value are read from here instead of bus -> bulk read, [0] contains offset

function GetBulkValue() {
    local register=$1
    local length=$2

    #echo "Read $register for $length - "
    local val=""
    register=$(($register - ${dataBlock[0]} + 1)) # fix offset
    length=$(($register + $length - 1))
    #echo "Start index $register, end index $length - "
    for (( ii=$register ; ii <= $length ; ii++ )); do
        val="$val ${dataBlock[ii]}"
    done
    echo $val
}

function ReadBulkData() {
    local register=$1
    local length=$2
    local ret

    local val=$($callModBus $register $length)
    ret=$?
    dataBlock=( $register $val )

    if [ $ret -eq 0 ]; then
        return $RETURN_SUCCESS
    else
        return $RETURN_FAILURE
    fi
}

function ClearBulkData() {
    unset dataBlock
}

function IsBulkAvailable() {
    if [[ ${dataBlock[@]:+${dataBlock[@]}} ]]; then
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
        if [ $val1 -gt 0 ]; then
            val2=$(($val1 / 256))
            if [ $val2 -gt 0 ]; then
                output=$output$(chr $val2)
            fi
            val2=$(($val1 % 256))
            if [ $val2 -gt 0 ]; then
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
    # val=${val#-}

    # if [ $val -eq 0 ]; then
    #     echo 1
    # elif [ $val -eq 1 ]; then
    #     echo 10
    # elif [ $val -eq 2 ]; then
    #     echo 100
    # elif [ $val -eq 3 ]; then
    #     echo 1000
    # fi
    return $ret
}

function GetScaledUInt32FloatValue() {
    local register=$1
    local scale=$2

    local val=$(GetUInt32Register $register)
    local ret=$?

    # numerical solution scale factor set to 1 / 10 / 100
    #m=34; awk -v m=$m 'BEGIN { print 1 - ((m - 20) / 34) }'

    # string solution - scale 0 / -1 / -2 / ..
    if [ "$scale" = "" ]; then
        scale=0
    fi
    if [ $scale -lt 0 -a $val -gt 0 ]; then
        local valLen=${#val}
        local sepPos=$(($valLen + $scale))
        if [ $sepPos -eq 0 ]; then 
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
        if [ $sepPos -eq 0 ]; then 
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
    echo "ID : $(GetStringRegister $(($invCommonBlock + 0)) 2)"
    echo "DID: $(GetUInt16Register $(($invCommonBlock + 2)))"
    echo "L  : $(GetUInt16Register $(($invCommonBlock + 3)))"
    echo "Mn : $(GetStringRegister $(($invCommonBlock + 4)) 16)"
    echo "Md : $(GetStringRegister $(($invCommonBlock + 19)) 16)"
    echo "Opt: $(GetStringRegister $(($invCommonBlock + 34)) 8)"
    echo "Vr : $(GetStringRegister $(($invCommonBlock + 42)) 8)"
    echo "SN : $(GetStringRegister $(($invCommonBlock + 50)) 16)"
    echo "DA : $(GetUInt16Register $(($invCommonBlock + 66)))"
    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadMeterCommonData() {
    ReadBulkData $meterCommonBlock 66
    echo "ID : $(GetUInt16Register $(($meterCommonBlock + 0)))"
    echo "L  : $(GetUInt16Register $(($meterCommonBlock + 1)))"
    echo "Mn : $(GetStringRegister $(($meterCommonBlock + 2)) 16)"
    echo "Md : $(GetStringRegister $(($meterCommonBlock + 18)) 16)"
    echo "Opt: $(GetStringRegister $(($meterCommonBlock + 34)) 8)"
    echo "Vr : $(GetStringRegister $(($meterCommonBlock + 42)) 8)"
    echo "SN : $(GetStringRegister $(($meterCommonBlock + 50)) 16)"
    echo "DA : $(GetUInt16Register $(($meterCommonBlock + 66)))"
    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadInverterID103() {
    # Check if we're on the right ID..
    local val
    local scale

    # Use bulk read - Get-funcs use this automatically
    ReadBulkData $invModel103Block 50

    val=$(GetUInt16Register $((invModel103Block + 0)))
    if [ $val -eq 103 ]; then
        echo "ID     : $val (matched)"
    else
        echo "ID     : $val (UNMATCHED - expected 103)"
        return $RETURN_FAILURE
    fi
    val=$(GetUInt16Register $((invModel103Block + 1)))
    if [ $val -eq 50 ]; then
        echo "L      : $val (matched)"
    else
        echo "L      : $val (UNMATCHED - expected 50)"
        return $RETURN_FAILURE
    fi

    scale=$(GetScaleFactor $((invModel103Block + 6)))
    #echo "Amp Scale $scale"
    echo "A      : $(GetScaledUInt16FloatValue $((invModel103Block + 2)) $scale) A"
    echo "AphA   : $(GetScaledUInt16FloatValue $((invModel103Block + 3)) $scale) A"
    echo "AphB   : $(GetScaledUInt16FloatValue $((invModel103Block + 4)) $scale) A"
    echo "AphC   : $(GetScaledUInt16FloatValue $((invModel103Block + 5)) $scale) A"

    scale=$(GetScaleFactor $((invModel103Block + 13)))
    echo "PPVphAB: $(GetScaledUInt16FloatValue $((invModel103Block + 7)) $scale) V"
    echo "PPVphBC: $(GetScaledUInt16FloatValue $((invModel103Block + 8)) $scale) V"
    echo "PPVphCA: $(GetScaledUInt16FloatValue $((invModel103Block + 9)) $scale) V"
    echo "PPVphA : $(GetScaledUInt16FloatValue $((invModel103Block + 10)) $scale) V"
    echo "PPVphB : $(GetScaledUInt16FloatValue $((invModel103Block + 11)) $scale) V"
    echo "PPVphC : $(GetScaledUInt16FloatValue $((invModel103Block + 12)) $scale) V"

    scale=$(GetScaleFactor $((invModel103Block + 15)))
    echo "W      : $(GetScaledUInt16FloatValue $((invModel103Block + 14)) $scale) W"

    scale=$(GetScaleFactor $((invModel103Block + 17)))
    echo "Hz     : $(GetScaledUInt16FloatValue $((invModel103Block + 16)) $scale) Hz"

    scale=$(GetScaleFactor $((invModel103Block + 19)))
    echo "VA     : $(GetScaledUInt16FloatValue $((invModel103Block + 18)) $scale) VA"

    scale=$(GetScaleFactor $((invModel103Block + 21)))
    echo "VAr    : $(GetScaledUInt16FloatValue $((invModel103Block + 20)) $scale) var"

    scale=$(GetScaleFactor $((invModel103Block + 23)))
    echo "PF     : $(GetScaledUInt16FloatValue $((invModel103Block + 22)) $scale) %"

    scale=$(GetScaleFactor $((invModel103Block + 26)))
    echo "WH     : $(GetScaledUInt32FloatValue $((invModel103Block + 24)) $scale) Wh"

    scale=$(GetScaleFactor $((invModel103Block + 28)))
    echo "DCA    : $(GetScaledUInt16FloatValue $((invModel103Block + 27)) $scale) A"

    scale=$(GetScaleFactor $((invModel103Block + 30)))
    echo "DCV    : $(GetScaledUInt16FloatValue $((invModel103Block + 29)) $scale) V"

    scale=$(GetScaleFactor $((invModel103Block + 32)))
    echo "DCW    : $(GetScaledUInt16FloatValue $((invModel103Block + 31)) $scale) W"

    scale=$(GetScaleFactor $((invModel103Block + 37)))
    #echo "TmpCab : $(GetScaledUInt16FloatValue $((invModel103Block + 33)) $scale) °C"   # mandatory but obviously not used..
    echo "TmpSnk : $(GetScaledUInt16FloatValue $((invModel103Block + 34)) $scale) °C"   # optional but filled
    #echo "TmpTrns: $(GetScaledUInt16FloatValue $((invModel103Block + 35)) $scale) °C"
    #echo "TmpOt  : $(GetScaledUInt16FloatValue $((invModel103Block + 36)) $scale) °C"

    echo "St     : $(GetInverterOperatingState $((invModel103Block + 38)))"
    echo "StVnd  : $(GetUInt16Register $((invModel103Block + 39)))"
    echo "Evt1   : $(GetInverterErrorState $((invModel103Block + 40)))" 

    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadMeterID203() {
    # Check if we're on the right ID..
    local val
    local scale

    # Use bulk read - Get-funcs use this automatically
    ReadBulkData $meterModel203Block 50

    val=$(GetUInt16Register $((meterModel203Block + 0)))
    if [ $val -eq 203 ]; then
        echo "ID           : $val (matched)"
    else
        echo "ID           : $val (UNMATCHED - expected 103)"
        return $RETURN_FAILURE
    fi
    val=$(GetUInt16Register $((meterModel203Block + 1)))
    if [ $val -eq 105 ]; then
        echo "L            : $val (matched)"
    else
        echo "L            : $val (UNMATCHED - expected 50)"
        return $RETURN_FAILURE
    fi

    scale=$(GetScaleFactor $((meterModel203Block + 6)))
    #echo "Amp Scale $scale"
    echo "A            : $(GetScaledUInt16FloatValue $((meterModel203Block + 2)) $scale) A"
    echo "AphA         : $(GetScaledUInt16FloatValue $((meterModel203Block + 3)) $scale) A"
    echo "AphB         : $(GetScaledUInt16FloatValue $((meterModel203Block + 4)) $scale) A"
    echo "AphC         : $(GetScaledUInt16FloatValue $((meterModel203Block + 5)) $scale) A"

    scale=$(GetScaleFactor $((meterModel203Block + 15)))
    echo "PhV          : $(GetScaledUInt16FloatValue $((meterModel203Block + 7)) $scale) V"
    echo "PhVphA       : $(GetScaledUInt16FloatValue $((meterModel203Block + 8)) $scale) V"
    echo "PhVphB       : $(GetScaledUInt16FloatValue $((meterModel203Block + 9)) $scale) V"
    echo "PVphC        : $(GetScaledUInt16FloatValue $((meterModel203Block + 10)) $scale) V"
    echo "PPV          : $(GetScaledUInt16FloatValue $((meterModel203Block + 11)) $scale) V"
    echo "PhVphAB      : $(GetScaledUInt16FloatValue $((meterModel203Block + 12)) $scale) V"
    echo "PhVphBC      : $(GetScaledUInt16FloatValue $((meterModel203Block + 13)) $scale) V"
    echo "PhVphCA      : $(GetScaledUInt16FloatValue $((meterModel203Block + 14)) $scale) V"

    scale=$(GetScaleFactor $((meterModel203Block + 17)))
    echo "Hz           : $(GetScaledUInt16FloatValue $((meterModel203Block + 16)) $scale) Hz"

    scale=$(GetScaleFactor $((meterModel203Block + 22)))
    echo "W            : $(GetScaledUInt16FloatValue $((meterModel203Block + 18)) $scale) W"
    echo "WphA         : $(GetScaledUInt16FloatValue $((meterModel203Block + 19)) $scale) W"
    echo "WphB         : $(GetScaledUInt16FloatValue $((meterModel203Block + 20)) $scale) W"
    echo "WphC         : $(GetScaledUInt16FloatValue $((meterModel203Block + 21)) $scale) W"

    scale=$(GetScaleFactor $((meterModel203Block + 27)))
    echo "VA           : $(GetScaledUInt16FloatValue $((meterModel203Block + 23)) $scale) VA"
    echo "VAphA        : $(GetScaledUInt16FloatValue $((meterModel203Block + 24)) $scale) VA"
    echo "VAphB        : $(GetScaledUInt16FloatValue $((meterModel203Block + 25)) $scale) VA"
    echo "VAphC        : $(GetScaledUInt16FloatValue $((meterModel203Block + 26)) $scale) VA"

    scale=$(GetScaleFactor $((meterModel203Block + 32)))
    echo "VAR          : $(GetScaledUInt16FloatValue $((meterModel203Block + 28)) $scale) var"
    echo "VARphA       : $(GetScaledUInt16FloatValue $((meterModel203Block + 29)) $scale) var"
    echo "VARphB       : $(GetScaledUInt16FloatValue $((meterModel203Block + 30)) $scale) var"
    echo "VARphC       : $(GetScaledUInt16FloatValue $((meterModel203Block + 31)) $scale) var"

    scale=$(GetScaleFactor $((meterModel203Block + 37)))
    echo "PF           : $(GetScaledUInt16FloatValue $((meterModel203Block + 33)) $scale) %"
    echo "PFphA        : $(GetScaledUInt16FloatValue $((meterModel203Block + 34)) $scale) %"
    echo "PFphB        : $(GetScaledUInt16FloatValue $((meterModel203Block + 35)) $scale) %"
    echo "PFphC        : $(GetScaledUInt16FloatValue $((meterModel203Block + 36)) $scale) %"

    scale=$(GetScaleFactor $((meterModel203Block + 54)))
    echo "TotWhExp     : $(GetScaledUInt32FloatValue $((meterModel203Block + 38)) $scale) Wh"
    echo "TotWhExpPhA  : $(GetScaledUInt32FloatValue $((meterModel203Block + 40)) $scale) Wh"
    echo "TotWhExpPhB  : $(GetScaledUInt32FloatValue $((meterModel203Block + 42)) $scale) Wh"
    echo "TotWhExpPnC  : $(GetScaledUInt32FloatValue $((meterModel203Block + 44)) $scale) Wh"
    echo "TotWhImp     : $(GetScaledUInt32FloatValue $((meterModel203Block + 46)) $scale) Wh"
    echo "TotWhImpPhA  : $(GetScaledUInt32FloatValue $((meterModel203Block + 48)) $scale) Wh"
    echo "TotWhImpPhB  : $(GetScaledUInt32FloatValue $((meterModel203Block + 50)) $scale) Wh"
    echo "TotWhImpPnC  : $(GetScaledUInt32FloatValue $((meterModel203Block + 52)) $scale) Wh"

    scale=$(GetScaleFactor $((meterModel203Block + 71)))
    echo "TotVAhExp    : $(GetScaledUInt32FloatValue $((meterModel203Block + 55)) $scale) VAh"
    echo "TotVAhExpPhA : $(GetScaledUInt32FloatValue $((meterModel203Block + 57)) $scale) VAh"
    echo "TotVAhExpPhB : $(GetScaledUInt32FloatValue $((meterModel203Block + 59)) $scale) VAh"
    echo "TotVAhExpPnC : $(GetScaledUInt32FloatValue $((meterModel203Block + 61)) $scale) VAh"
    echo "TotVAhImp    : $(GetScaledUInt32FloatValue $((meterModel203Block + 63)) $scale) VAh"
    echo "TotVAhImpPhA : $(GetScaledUInt32FloatValue $((meterModel203Block + 65)) $scale) VAh"
    echo "TotVAhImpPhB : $(GetScaledUInt32FloatValue $((meterModel203Block + 67)) $scale) VAh"
    echo "TotVAhImpPhC : $(GetScaledUInt32FloatValue $((meterModel203Block + 69)) $scale) VAh"

    scale=$(GetScaleFactor $((meterModel203Block + 104)))
    echo "TotVArhImpQ1   : $(GetScaledUInt32FloatValue $((meterModel203Block + 72)) $scale) varh"
    echo "TotVArhImpQ1PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 74)) $scale) varh"
    echo "TotVArhImpQ1PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 76)) $scale) varh"
    echo "TotVArhImpQ1PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 78)) $scale) varh"
    echo "TotVArhImpQ2   : $(GetScaledUInt32FloatValue $((meterModel203Block + 80)) $scale) varh"
    echo "TotVArhImpQ2PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 82)) $scale) varh"
    echo "TotVArhImpQ2PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 84)) $scale) varh"
    echo "TotVArhImpQ2PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 86)) $scale) varh"
    echo "TotVArhExpQ3   : $(GetScaledUInt32FloatValue $((meterModel203Block + 88)) $scale) varh"
    echo "TotVArhExpQ3PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 90)) $scale) varh"
    echo "TotVArhExpQ3PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 92)) $scale) varh"
    echo "TotVArhExpQ3PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 94)) $scale) varh"
    echo "TotVArhExpQ4   : $(GetScaledUInt32FloatValue $((meterModel203Block + 96)) $scale) varh"
    echo "TotVArhExpQ4PhA: $(GetScaledUInt32FloatValue $((meterModel203Block + 98)) $scale) varh"
    echo "TotVArhExpQ4PhB: $(GetScaledUInt32FloatValue $((meterModel203Block + 100)) $scale) varh"
    echo "TotVArhExpQ4PhC: $(GetScaledUInt32FloatValue $((meterModel203Block + 102)) $scale) varh"

    echo "Evt          : $(GetMeterErrorState $((meterModel203Block + 105)))"
}

# IsBulkAvailable
# echo "1 = $?"
# dataBlock=(256)
# IsBulkAvailable
# echo "0 = $?"
# dataBlock=(256 3)
# unset dataBlock[0]
# IsBulkAvailable
# echo "0 = $?"
# unset dataBlock[0]
# IsBulkAvailable
# echo "1/0 = $?"
# ClearBulkData
# IsBulkAvailable
# echo "1 = $?"

# ReadBulkData $invModel103Block 50
# IsBulkAvailable
# echo "0 = $?"
# echo "dataBlock: ${dataBlock[*]}"
# echo "# in dataBlock ${#dataBlock[*]}"
# echo $(GetBulkValue $((invModel103Block + 0)) 1)
# echo $(GetBulkValue $((invModel103Block + 2)) 6)
# echo $(GetBulkValue $((invModel103Block + 6)) 54)
# echo $(GetModBusValue $((invModel103Block + 0)) 1)
# echo $(GetModBusValue $((invModel103Block + 2)) 6)
# echo $(GetModBusValue $((invModel103Block + 6)) 54)
# ClearBulkData

ReadInverterCommonData
ReadMeterCommonData
echo ""
ReadInverterID103
echo ""
ReadMeterID203