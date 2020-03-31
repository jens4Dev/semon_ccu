#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

# library to read values from SolarEdge Inverter & Meter via ModBus TCP

# data cache
namespace eval SE_modBus {
   variable dataList
   variable dataArray
   variable DECSEPERATOR
}
set ::SE_modBus::DECSEPERATOR .

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
    
    if { $scale < 0 && $val != 0 } {
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
