#!/usr/bin/env bash
#

# Experimente...

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0


# Settings
inverterIP="192.168.30.45"
inverterModBusPort="502"

callModBus="tclsh /usr/local/addons/modbus/modbus_interface.tcl $inverterIP $inverterModBusPort 1 03" # fiex on ID 1 & Read

invCommonBlock=40000
invModelBlockStart=40069
meterCommonBlock=40121
meterModelBlock=40188

function GetModBusValue() {
    local register=$1
    local length=$2

    local ret=$($callModBus $register $length)
    echo "$ret"
    return ${RETURN_SUCCESS}
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
    # echo $val
    val=${val#-}

    if [ $val -eq 0 ]; then
        echo 1
    elif [ $val -eq 1 ]; then
        echo 10
    elif [ $val -eq 2 ]; then
        echo 100
    elif [ $val -eq 3 ]; then
        echo 1000
    fi
    return $?
}

function GetScaledUin32FloatValue() {
    local register=$1
    local length=$2
    local scale=$3
    
    m=34; awk -v m=$m 'BEGIN { print 1 - ((m - 20) / 34) }'
}

# String SunS = 0x53756e53 = 1400204883
invSunSValue=$(GetUInt32Register $(($invCommonBlock + 0)))
echo "Hier $invSunSValue"

invSunSstring=$(GetStringRegister $(($invCommonBlock + 0)) 2)
echo "Hier $invSunSstring"

# C_Hersteller
invVendor=$(GetStringRegister $(($invCommonBlock + 4)) 16)
echo "Hier $invVendor"

# C_Modell
invModell=$(GetStringRegister $(($invCommonBlock + 20)) 16)
echo "Hier $invModell"

# C_Version
invVersion=$(GetStringRegister $(($invCommonBlock + 44)) 8)
echo "Hier $invVersion"

# C_Serial
invSerialNo=$(GetStringRegister $(($invCommonBlock + 52)) 16)
echo "Hier $invSerialNo"

# SunSpec Mapping IDs
invMapID=$(GetUInt16Register $(($invCommonBlock + 69)))
echo "Hier $invMapID"

# Scale
GetScaleFactor $(($invModelBlockStart + 15))

meterSunSstring=$(GetStringRegister $(($meterCommonBlock + 0)) 2)
echo "Hier $meterSunSstring"

# C_Hersteller
meterVendor=$(GetStringRegister $(($meterCommonBlock + 4)) 16)
echo "Hier $meterVendor"

# C_Modell
meterModell=$(GetStringRegister $(($meterCommonBlock + 20)) 16)
echo "Hier $meterModell"

# C_Version
meterVersion=$(GetStringRegister $(($meterCommonBlock + 44)) 8)
echo "Hier $meterVersion"

# C_Serial
meterSerialNo=$(GetStringRegister $(($meterCommonBlock + 52)) 16)
echo "Hier $meterSerialNo"

# SunSpec Mapping IDs
meterMapID=$(GetUInt16Register $(($meterCommonBlock + 69)))
echo "Hier $meterMapID"
