callModBus="tclsh $DIR/modbus_interface.tcl $SE_INVERTER_IP $SE_INVERTER_MODBUS_PORT 1 03" # fix on ID 1 & Read

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
        1 ) echo "Off";;            # Device is not operating
        2 ) echo "Sleeping";;       # Device is sleeping / auto-shudown
        3 ) echo "Starting";;       # Device is starting up
        4 ) echo "Running";;        # MPPT: Device is auto tracking maximum power point
        5 ) echo "Throttled";;      # Device is operating at reduced power output
        6 ) echo "Shutting down";;  # Device is shutting down
        7 ) echo "Fault";;          # One or more faults exist
        9 ) echo "Standby";;        # Device is in standby mode
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
    if [ $? -ne $RETURN_SUCCESS ]; then
        return $RETURN_FAILURE
    fi

    # inverter does not follow SunSpec ID 1 completely....
    inverterData_ID=$(GetStringRegister $(($invCommonBlock + 0)) 2)
    inverterData_DID=$(GetUInt16Register $(($invCommonBlock + 2)))
    inverterData_L=$(GetUInt16Register $(($invCommonBlock + 3)))
    inverterData_Mn=$(GetStringRegister $(($invCommonBlock + 4)) 16)
    inverterData_Md=$(GetStringRegister $(($invCommonBlock + 19)) 16)
    inverterData_Opt=$(GetStringRegister $(($invCommonBlock + 34)) 8)
    inverterData_Vr=$(GetStringRegister $(($invCommonBlock + 42)) 8)
    inverterData_SN=$(GetStringRegister $(($invCommonBlock + 50)) 16)
    inverterData_DA=$(GetUInt16Register $(($invCommonBlock + 66)))
    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadMeterCommonData() {
    ReadBulkData $meterCommonBlock 66
    if [ $? -ne $RETURN_SUCCESS ]; then
        return $RETURN_FAILURE
    fi

    meterData_ID=$(GetUInt16Register $(($meterCommonBlock + 0)))
    meterData_L=$(GetUInt16Register $(($meterCommonBlock + 1)))
    meterData_Mn=$(GetStringRegister $(($meterCommonBlock + 2)) 16)
    meterData_Md=$(GetStringRegister $(($meterCommonBlock + 18)) 16)
    meterData_Opt=$(GetStringRegister $(($meterCommonBlock + 34)) 8)
    meterData_Vr=$(GetStringRegister $(($meterCommonBlock + 42)) 8)
    meterData_SN=$(GetStringRegister $(($meterCommonBlock + 50)) 16)
    meterData_DA=$(GetUInt16Register $(($meterCommonBlock + 66)))
    ClearBulkData

    return $RETURN_SUCCESS
}

function ReadInverterGeneralStatus() {
    local scale

    # Check if we're on the right ID..
    inverterData_ID=$(GetUInt16Register $((invModel103Block + 0)))
    if (( inverterData_ID != 103 )); then
        echo "ID     : $inverterData_ID (UNMATCHED - expected 103)"
        return $RETURN_FAILURE
    fi
    inverterData_L=$(GetUInt16Register $((invModel103Block + 1)))
    if (( inverterData_L != 50 )); then
        echo "L      : $inverterData_L (UNMATCHED - expected 50)"
        return $RETURN_FAILURE
    fi

    scale=$(GetScaleFactor $((invModel103Block + 37)))
    #inverterData_TmpCab__C="$(GetScaledUInt16FloatValue $((invModel103Block + 33)) $scale)"   # mandatory but obviously not used..
    inverterData_TmpSnk__C="$(GetScaledUInt16FloatValue $((invModel103Block + 34)) $scale)"    # optional but filled
    #inverterData_TmpTrns__C="$(GetScaledUInt16FloatValue $((invModel103Block + 35)) $scale)"  # seems unused
    #inverterData_TmpOt__C="$(GetScaledUInt16FloatValue $((invModel103Block + 36)) $scale)"    # seems unused

    inverterData_St="$(GetInverterOperatingState $((invModel103Block + 38)))"
    inverterData_StVnd="$(GetUInt16Register $((invModel103Block + 39)))"
    inverterData_Evt1="$(GetInverterErrorState $((invModel103Block + 40)))" 
}

function ReadBulkDataInverter() {
    ReadBulkData $invModel103Block 50
    return $?
}

function ReadInverterBaseData() {
    local scale

    scale=$(GetScaleFactor $((invModel103Block + 6)))
    inverterData_A__A="$(GetScaledUInt16FloatValue $((invModel103Block + 2)) $scale)"
    inverterData_AphA__A="$(GetScaledUInt16FloatValue $((invModel103Block + 3)) $scale)"
    inverterData_AphB__A="$(GetScaledUInt16FloatValue $((invModel103Block + 4)) $scale)"
    inverterData_AphC__A="$(GetScaledUInt16FloatValue $((invModel103Block + 5)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 15)))
    inverterData_W__W="$(GetScaledUInt16FloatValue $((invModel103Block + 14)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 26)))
    inverterData_WH__Wh="$(GetScaledUInt32FloatValue $((invModel103Block + 24)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 28)))
    inverterData_DCA__A="$(GetScaledUInt16FloatValue $((invModel103Block + 27)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 30)))
    inverterData_DCV__V="$(GetScaledUInt16FloatValue $((invModel103Block + 29)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 32)))
    inverterData_DCW__W="$(GetScaledUInt16FloatValue $((invModel103Block + 31)) $scale)"

    return $RETURN_SUCCESS
}

function ReadInverterFullData() {
    local scale

    scale=$(GetScaleFactor $((invModel103Block + 6)))
    inverterData_A__A="$(GetScaledUInt16FloatValue $((invModel103Block + 2)) $scale)"
    inverterData_AphA__A="$(GetScaledUInt16FloatValue $((invModel103Block + 3)) $scale)"
    inverterData_AphB__A="$(GetScaledUInt16FloatValue $((invModel103Block + 4)) $scale)"
    inverterData_AphC__A="$(GetScaledUInt16FloatValue $((invModel103Block + 5)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 13)))
    inverterData_PPVphAB__V="$(GetScaledUInt16FloatValue $((invModel103Block + 7)) $scale)"
    inverterData_PPVphBC__V="$(GetScaledUInt16FloatValue $((invModel103Block + 8)) $scale)"
    inverterData_PPVphCA__V="$(GetScaledUInt16FloatValue $((invModel103Block + 9)) $scale)"
    inverterData_PPVphA__V="$(GetScaledUInt16FloatValue $((invModel103Block + 10)) $scale)"
    inverterData_PPVphB__V="$(GetScaledUInt16FloatValue $((invModel103Block + 11)) $scale)"
    inverterData_PPVphC__V="$(GetScaledUInt16FloatValue $((invModel103Block + 12)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 15)))
    inverterData_W__W="$(GetScaledUInt16FloatValue $((invModel103Block + 14)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 17)))
    inverterData_Hz__Hz="$(GetScaledUInt16FloatValue $((invModel103Block + 16)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 19)))
    inverterData_VA__VA="$(GetScaledUInt16FloatValue $((invModel103Block + 18)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 21)))
    inverterData_VAr__var="$(GetScaledUInt16FloatValue $((invModel103Block + 20)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 23)))
    inverterData_PF__perct="$(GetScaledUInt16FloatValue $((invModel103Block + 22)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 26)))
    inverterData_WH__Wh="$(GetScaledUInt32FloatValue $((invModel103Block + 24)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 28)))
    inverterData_DCA__A="$(GetScaledUInt16FloatValue $((invModel103Block + 27)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 30)))
    inverterData_DCV__V="$(GetScaledUInt16FloatValue $((invModel103Block + 29)) $scale)"

    scale=$(GetScaleFactor $((invModel103Block + 32)))
    inverterData_DCW__W="$(GetScaledUInt16FloatValue $((invModel103Block + 31)) $scale)"

    return $RETURN_SUCCESS
}

function ReadBulkDataMeter() {
    ReadBulkData $meterModel203Block 150
    return $?
}

function ReadMeterBaseData() {
    local scale

    scale=$(GetScaleFactor $((meterModel203Block + 6)))
    meterData_A__A="$(GetScaledUInt16FloatValue $((meterModel203Block + 2)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 15)))
    meterData_PhV__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 7)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 22)))
    meterData_W__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 18)) $scale)"
    meterData_WphA__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 19)) $scale)"
    meterData_WphB__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 20)) $scale)"
    meterData_WphC__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 21)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 54)))
    meterData_TotWhExp__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 38)) $scale)"
    meterData_TotWhExpPhA__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 40)) $scale)"
    meterData_TotWhExpPhB__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 42)) $scale)"
    meterData_TotWhExpPnC__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 44)) $scale)"
    meterData_TotWhImp__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 46)) $scale)"
    meterData_TotWhImpPhA__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 48)) $scale)"
    meterData_TotWhImpPhB__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 50)) $scale)"
    meterData_TotWhImpPnC__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 52)) $scale)"

    return $RETURN_SUCCESS
}

function ReadMeterGeneralStatus() {
    local scale

    # Check if we're on the right ID..
    meterData_ID=$(GetUInt16Register $((meterModel203Block + 0)))
    if (( meterData_ID != 203 )); then
        echo "ID           : $meterData_ID (UNMATCHED - expected 103)"
        return $RETURN_FAILURE
    fi
    meterData_L=$(GetUInt16Register $((meterModel203Block + 1)))
    if (( meterData_L != 105 )); then
        echo "L            : $meterData_L (UNMATCHED - expected 50)"
        return $RETURN_FAILURE
    fi

    meterData_Evt="$(GetMeterErrorState $((meterModel203Block + 105)))"

    return $RETURN_SUCCESS
}

function ReadMeterFullData() {
    local scale

    scale=$(GetScaleFactor $((meterModel203Block + 6)))
    meterData_A__A="$(GetScaledUInt16FloatValue $((meterModel203Block + 2)) $scale)"
    meterData_AphA__A="$(GetScaledUInt16FloatValue $((meterModel203Block + 3)) $scale)"
    meterData_AphB__A="$(GetScaledUInt16FloatValue $((meterModel203Block + 4)) $scale)"
    meterData_AphC__A="$(GetScaledUInt16FloatValue $((meterModel203Block + 5)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 15)))
    meterData_PhV__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 7)) $scale)"
    meterData_PhVphA__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 8)) $scale)"
    meterData_PhVphB__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 9)) $scale)"
    meterData_PVphC__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 10)) $scale)"
    meterData_PPV__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 11)) $scale)"
    meterData_PhVphAB__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 12)) $scale)"
    meterData_PhVphBC__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 13)) $scale)"
    meterData_PhVphCA__V="$(GetScaledUInt16FloatValue $((meterModel203Block + 14)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 17)))
    meterData_Hz__Hz="$(GetScaledUInt16FloatValue $((meterModel203Block + 16)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 22)))
    meterData_W__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 18)) $scale)"
    meterData_WphA__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 19)) $scale)"
    meterData_WphB__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 20)) $scale)"
    meterData_WphC__W="$(GetScaledUInt16FloatValue $((meterModel203Block + 21)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 27)))
    meterData_VA__VA="$(GetScaledUInt16FloatValue $((meterModel203Block + 23)) $scale)"
    meterData_VAphA__VA="$(GetScaledUInt16FloatValue $((meterModel203Block + 24)) $scale)"
    meterData_VAphB__VA="$(GetScaledUInt16FloatValue $((meterModel203Block + 25)) $scale)"
    meterData_VAphC__VA="$(GetScaledUInt16FloatValue $((meterModel203Block + 26)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 32)))
    meterData_VAR__var="$(GetScaledUInt16FloatValue $((meterModel203Block + 28)) $scale)"
    meterData_VARphA__var="$(GetScaledUInt16FloatValue $((meterModel203Block + 29)) $scale)"
    meterData_VARphB__var="$(GetScaledUInt16FloatValue $((meterModel203Block + 30)) $scale)"
    meterData_VARphC__var="$(GetScaledUInt16FloatValue $((meterModel203Block + 31)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 37)))
    meterData_PF__perct="$(GetScaledUInt16FloatValue $((meterModel203Block + 33)) $scale)"
    meterData_PFphA__perct="$(GetScaledUInt16FloatValue $((meterModel203Block + 34)) $scale)"
    meterData_PFphB__perct="$(GetScaledUInt16FloatValue $((meterModel203Block + 35)) $scale)"
    meterData_PFphC__perct="$(GetScaledUInt16FloatValue $((meterModel203Block + 36)) $scale)"

    scale=$(GetScaleFactor $((meterModel203Block + 54)))
    meterData_TotWhExp__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 38)) $scale)"
    meterData_TotWhExpPhA__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 40)) $scale)"
    meterData_TotWhExpPhB__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 42)) $scale)"
    meterData_TotWhExpPnC__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 44)) $scale)"
    meterData_TotWhImp__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 46)) $scale)"
    meterData_TotWhImpPhA__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 48)) $scale)"
    meterData_TotWhImpPhB__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 50)) $scale)"
    meterData_TotWhImpPnC__Wh="$(GetScaledUInt32FloatValue $((meterModel203Block + 52)) $scale)"

    # looks unsed in WattNode SE-WND-3Y-400-MB

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

    return $RETURN_SUCCESS
}