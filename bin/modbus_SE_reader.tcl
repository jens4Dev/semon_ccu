#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

if { $argc != 4 } {
  puts ""
  puts "The modbus_SE_reader.tcl script requires xx numbers to be given."
  puts "(IP, Port, Function (Data-Block) and output-type for reading SolarEdge Inverter and Wattnode Meter."
  puts "For example: 192.168.178.35 502 Inverter SH"
  puts " "
  puts "Output comes in a parseable form for different languages - JSON or SH ((bash-)shell)  "
  puts "IP/FQDN DNS-hostname or IP-adress of SolarEdge Inverter"
  puts "Port 	client port for ModBus TCP"
  puts "Func 	CommonInv   - read Inverter common block"
  puts "     	CommonMeter - read Meter common block"
  puts "		Inverter    - read Inverter data block (SunSpec ID 103 with SE-changes..)"
  puts "		Meter       - read Meter data block (SunSpec ID 203)"
  puts "Output  JSON - Output values in JSON-array"
  puts "        SH   - Output values in baSH-parseable form"
  puts ""
  puts "Please try again."
  exit 1
}

# Modus TCP (always!)

# Include lib - must in same dir as this script
set script_path [ file dirname [ info script ] ]
source $script_path/modbus.tcl

# Set configuration
::modbus::configure -mode "TCP" -ip "[lindex $argv 0]" -port "[lindex $argv 1]"

# Config values
set invDeviceID 1
set invCommonBlock 40000
set invCommonBlockLen 66
set invModel103Block 40069
set invModel103BlockLen 50
set meterCommonBlock 40121
set meterCommonBlockLen 66
set meterModel203Block 40188
set meterModel203BlockLen 50
# data cache
namespace eval SE_modBus {
   variable dataList
   variable DECSEPERATOR
}
set ::SE_modBus::DECSEPERATOR .

switch -- [lindex $argv 2] {
    "CommonInv" {
        set block $invCommonBlock
        set len $invCommonBlockLen
    }
    "CommonMeter" {
        set block $meterCommonBlock
        set len $meterCommonBlockLen
    }
    "Inverter" {
        set block $invModel103Block
        set len $invModel103BlockLen
    }
    "Meter" {
        set block $invModel103Block
        set len $meterCommonBlockLen
    }
    default {
        puts "Unkown function [lindex $argv 3]!"
        exit 1
    }
}

# send parameters and receive answer
set dataBlock [::modbus::cmd "03" $invDeviceID $block $len]
#puts $dataBlock 
set ::SE_modBus::dataList [split "$dataBlock" " "]
if { [ llength $::SE_modBus::dataList ] != $len } {
    puts "Data corrupted - found [ llength $::SE_modBus::dataList ] instead if $len"
    exit 1
}

proc GetUInt16Register {register} {
    return [ lindex $::SE_modBus::dataList $register ]
}

proc GetUInt32Register {register} {
    set highByte [ lindex $::SE_modBus::dataList $register ]
    set lowByte [ lindex $::SE_modBus::dataList [ expr $register + 1]]
    return [ expr ($highByte * 65536) + $lowByte ]
}

proc GetStringRegister {register length} {
    set vals [ lrange $::SE_modBus::dataList $register [ expr $register + $length - 1] ]
    set output ""

    foreach item $vals {
        set lowByte [ expr $item / 256 ]
        set highByte [ expr $item % 256 ]
        if { $lowByte > 0 } {
            set char [format %c $lowByte]
            set output $output$char
        }
        if { $highByte > 0 } {
            set char [format %c $highByte]
            set output $output$char
        }
    }
    return $output
}

proc ScaleValue {val scale} {
    if { $scale == "" } {
        scale=0
    }

    if { $scale < 0 && $val > 0 } {
        set valLen [ string length $val ]
        set sepPos [ expr $valLen + $scale ]

        if { $sepPos <= 0 } {
            set repCnt [ expr ( $sepPos * (-1) ) + 1]
            set val "[string repeat 0 $repCnt]$val"
            set sepPos [ expr ($sepPos + $repCnt)]
        } 
        return "[string range $val 0 [expr $sepPos - 1]]$::SE_modBus::DECSEPERATOR[string range $val $sepPos end]"
    }
    return $val
}

proc GetScaledUInt16FloatValue {register scale} {
    set val [ GetUInt16Register $register ]
    return [ ScaleValue $val $scale ]
}

proc GetScaledUInt32FloatValue {register scale} {
    set val [ GetUInt32Register $register ]
    return [ ScaleValue $val $scale ]
}

proc GetInverterOperatingState {register} {
    switch -- [ GetUInt16Register $register ] {
        "1"     { 
            # Device is not operating
            return "Off" }                    
        "2"     { 
            # Device is sleeping / auto-shudown
            return "Sleeping" }       
        "3"     { 
            # Device is starting up
            return "Starting" }       
        "4"     { 
            # MPPT: Device is auto tracking maximum power point
            return "Running" }        
        "5"     { 
            # Device is operating at reduced power output
            return "Throttled" }      
        "6"     { 
             # Device is shutting down
            return "Shutting down" }  
        "7"     { 
            # One or more faults exist
            return "Fault" }          
        "9"     { 
            # Device is in standby mode
            return "Standby" }        
        default { return "Unknown operating state no [ GetUInt16Register $register ]"}
    }
}

proc GetInverterErrorState {register} {
    switch -- [ GetUInt16Register $register ] {
        "-1"    { return "None" }
        "0"     { return "Ground fault"}
        "1"     { return "DC over voltage"}
        "2"     { return "AC disconnect open"}
        "3"     { return "DC disconnect open"}
        "4"     { return "Grid shutdown"}
        "5"     { return "Cabinet open"}
        "6"     { return "Manual shutdown"}
        "7"     { return "Over temperature"}
        "8"     { return "Frequency above limit"}
        "9"     { return "Frequency under limit"}
        "10"    { return "AC Voltage above limit"}
        "11"    { return "AC Voltage under limit"}
        "12"    { return "Blown String fuse on input"}
        "13"    { return "Under temperature"}
        "14"    { return "Generic Memory or Communication error (internal)"}
        "15"    { return "Hardware test failure"}
        default { return "Unknown error state no [ GetUInt16Register $register ]"}
    }
}

proc GetMeterErrorState {register} {
    switch -- [ GetUInt16Register $register ] {
        "0"     { return "None"}
        ""      { return "None"}
        "2"     { return "Power Failure"}
        "3"     { return "Under Voltage"}
        "4"     { return "Low PF"}
        "5"     { return "Over Current"}
        "6"     { return "Over Voltage"}
        "7"     { return "Missing Sensor"}
        default { return "Unknown error state no [ GetUInt16Register $register ]"}
    }
}

switch -- [lindex $argv 2] {
    "CommonInv" {
        puts [ GetUInt16Register 0 ]
        puts [ GetUInt16Register 1 ]
        puts [ GetUInt32Register 0 ]
        puts [ GetStringRegister 0 2 ]
        puts [ GetUInt16Register 2 ]
        puts [ GetUInt16Register 3 ]
        puts [ GetStringRegister 4 16 ]
        puts [ GetStringRegister 19 16 ]
    }
    "CommonMeter" {
    }
    "Inverter" {
        puts [ GetUInt16Register 0 ]
        puts [ GetUInt16Register 1 ]
        set scale [ GetUInt16Register 37 ]
        puts [ GetScaledUInt16FloatValue 34 $scale ] 
#        puts [ GetScaledUInt16FloatValue 35 $scale ] 
 #       puts [ GetScaledUInt16FloatValue 36 $scale ]   
        puts [ GetInverterOperatingState 38 ]
        puts [ GetUInt16Register 39 ]
        puts [ GetInverterErrorState 40 ]
        set scale [ GetUInt16Register 26 ]
        puts [GetScaledUInt32FloatValue 24 $scale ]
    }
    "Meter" {
    }
}
#END
