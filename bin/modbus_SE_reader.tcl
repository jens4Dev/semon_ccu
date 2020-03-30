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
source $script_path/modbus_SE_reader_lib.tcl

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
set meterModel203BlockLen 105

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
        set block $meterModel203Block
        set len $meterModel203BlockLen
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

switch -- [lindex $argv 2] {
    "CommonInv" {
        # inverter does not follow SunSpec ID 1 completely....
        # indirect creation of an array - in lists there is evaluation in tcl..
        set dataString "inverterCData_ID \"[ GetStringRegister 0 2 ]\"
                        inverterCData_DID \"[ GetUInt16Register 2 ]\"
                        inverterCData_L \"[ GetUInt16Register 3 ]\"
                        inverterCData_Mn \"[ GetStringRegister 4 16 ]\"
                        inverterCData_Md \"[ GetStringRegister 19 16 ]\"
                        inverterCData_Opt \"[ GetStringRegister 34 8 ]\"
                        inverterCData_Vr \"[ GetStringRegister 42 8 ]\"
                        inverterCData_SN \"[ GetStringRegister 50 16 ]\"
                        inverterCData_DA \"[ GetUInt16Register 66 ]\""
        array set ::SE_modBus::dataArray $dataString
        foreach { item value } [ array get ::SE_modBus::dataArray ] {
            puts "$item=$value"
        }
    }
    "CommonMeter" {
        set dataString "
                        meterCData_ID \"[ GetUInt16Register 0 ]\"
                        meterCData_L \"[ GetUInt16Register 1 ]\"
                        meterCData_Mn \"[ GetStringRegister 2 16 ]\"
                        meterCData_Md \"[ GetStringRegister 18 16 ]\"
                        meterCData_Opt \"[ GetStringRegister 34 8 ]\"
                        meterCData_Vr \"[ GetStringRegister 42 8 ]\"
                        meterCData_SN \"[ GetStringRegister 50 16 ]\"
                        meterCData_DA \"[ GetUInt16Register 66 ]\""
        array set ::SE_modBus::dataArray $dataString
    }
    "Inverter" {
        set scale_A [ GetUInt16Register 6 ]
        set scale_PPV [ GetUInt16Register 13 ]
        # inverterData_TmpSnk__C is officially optional but filled in SE - register 33 is mandatory but not used..
        set dataString "inverterData_ID \"[ GetUInt16Register 0 ]\"
                        inverterData_L \"[ GetUInt16Register 1 ]\"
                        inverterData_A__A \"[ GetScaledUInt16FloatValue 2 $scale_A ]\"
                        inverterData_AphA__A \"[ GetScaledUInt16FloatValue 3 $scale_A ]\"
                        inverterData_AphB__A \"[ GetScaledUInt16FloatValue 4 $scale_A ]\"
                        inverterData_AphC__A \"[ GetScaledUInt16FloatValue 5 $scale_A ]\"
                        inverterData_PPVphAB__V \"[ GetScaledUInt16FloatValue 7 $scale_PPV ]\"
                        inverterData_PPVphBC__V \"[ GetScaledUInt16FloatValue 8 $scale_PPV ]\"
                        inverterData_PPVphCA__V \"[ GetScaledUInt16FloatValue 9 $scale_PPV ]\"
                        inverterData_PPVphA__V \"[ GetScaledUInt16FloatValue 10 $scale_PPV ]\"
                        inverterData_PPVphB__V \"[ GetScaledUInt16FloatValue 11 $scale_PPV ]\"
                        inverterData_PPVphC__V \"[ GetScaledUInt16FloatValue 12 $scale_PPV ]\"
                        inverterData_W__W [ GetScaledUInt16FloatValue 14 [ GetUInt16Register 15 ] ]
                        inverterData_Hz__Hz [ GetScaledUInt16FloatValue 16 [ GetUInt16Register 17 ] ]
                        inverterData_VA__VA [ GetScaledUInt16FloatValue 18 [ GetUInt16Register 19 ] ]
                        inverterData_VAr__var [ GetScaledUInt16FloatValue 20 [ GetUInt16Register 21 ] ]
                        inverterData_PF__perct [ GetScaledUInt16FloatValue 22 [ GetUInt16Register 23 ] ]
                        inverterData_WH__kWh [ GetScaledUInt32FloatValue 24 [ expr [ GetUInt16Register 26 ] -3 ] ]
                        inverterData_DCA__A [ GetScaledUInt16FloatValue 27 [ GetUInt16Register 28 ] ]
                        inverterData_DCV__V [ GetScaledUInt16FloatValue 29 [ GetUInt16Register 30 ] ]
                        inverterData_DCW__W [ GetScaledUInt16FloatValue 31 [ GetUInt16Register 32 ] ]
                        inverterData_TmpSnk__C [ GetScaledUInt16FloatValue 34 [ GetUInt16Register 37 ] ]
                        inverterData_St \"[ GetInverterOperatingState 38 ]\"
                        inverterData_StVnd \"[ GetUInt16Register 39 ]\"
                        inverterData_Evt1 \"[ GetInverterErrorState 40 ]\""
        array set ::SE_modBus::dataArray $dataString
        if { $::SE_modBus::dataArray(inverterData_ID) != 103 } {
            puts "inverterData_ID : $::SE_modBus::dataArray(inverterData_ID) (UNMATCHED - expected 103)"
            exit 1
        }
        if { $::SE_modBus::dataArray(inverterData_L) != 50 } {
            puts "inverterData_L  : $::SE_modBus::dataArray(inverterData_L) (UNMATCHED - expected 50)"
            exit 1
        }
    }
    "Meter" {
        set scaleA "[ GetUInt16Register 6 ]"
        set scalePhV "[ GetUInt16Register 15 ]"
        set scaleW "[ GetUInt16Register 22 ]"
        set scaleVA "[ GetUInt16Register 27 ]"
        set scaleVAR "[ GetUInt16Register 32 ]"
        set scalePF "[ GetUInt16Register 37 ]"
        set scaleTotWh [expr [ GetUInt16Register 54 ] - 3 ]
        set meterData_TotWhImpPhB__kWh "[ GetScaledUInt32FloatValue 50 $scaleTotWh ]"

        set dataString "meterData_ID \"[ GetUInt16Register 0 ]\"
                        meterData_L \"[ GetUInt16Register 1 ]\"
                        meterData_A__A \"[ GetScaledUInt16FloatValue 2 $scaleA ]\"
                        meterData_AphA__A \"[ GetScaledUInt16FloatValue 3 $scaleA ]\"
                        meterData_AphB__A \"[ GetScaledUInt16FloatValue 4 $scaleA ]\"
                        meterData_AphC__A \"[ GetScaledUInt16FloatValue 5 $scaleA ]\"
                        meterData_PhV__V \"[ GetScaledUInt16FloatValue 7 $scalePhV ]\"
                        meterData_PhVphA__V \"[ GetScaledUInt16FloatValue 8 $scalePhV ]\"
                        meterData_PhVphB__V \"[ GetScaledUInt16FloatValue 9 $scalePhV ]\"
                        meterData_PVphC__V \"[ GetScaledUInt16FloatValue 10 $scalePhV ]\"
                        meterData_PPV__V \"[ GetScaledUInt16FloatValue 11 $scalePhV ]\"
                        meterData_PhVphAB__V \"[ GetScaledUInt16FloatValue 12 $scalePhV ]\"
                        meterData_PhVphBC__V \"[ GetScaledUInt16FloatValue 13 $scalePhV ]\"
                        meterData_PhVphCA__V \"[ GetScaledUInt16FloatValue 14 $scalePhV ]\"
                        meterData_Hz__Hz [ GetScaledUInt16FloatValue 16 [ GetUInt16Register 17 ] ]
                        meterData_W__W \"[ GetScaledUInt16FloatValue 18 $scaleW ]\"
                        meterData_WphA__W \"[ GetScaledUInt16FloatValue 19 $scaleW ]\"
                        meterData_WphB__W \"[ GetScaledUInt16FloatValue 20 $scaleW ]\"
                        meterData_WphC__W \"[ GetScaledUInt16FloatValue 21 $scaleW ]\"
                        meterData_VA__VA \"[ GetScaledUInt16FloatValue 23 $scaleVA ]\"
                        meterData_VAphA__VA \"[ GetScaledUInt16FloatValue 24 $scaleVA ]\"
                        meterData_VAphB__VA \"[ GetScaledUInt16FloatValue 25 $scaleVA ]\"
                        meterData_VAphC__VA \"[ GetScaledUInt16FloatValue 26 $scaleVA ]\"
                        meterData_VAR__var \"[ GetScaledUInt16FloatValue 28 $scaleVAR ]\"
                        meterData_VARphA__var \"[ GetScaledUInt16FloatValue 29 $scaleVAR ]\"
                        meterData_VARphB__var \"[ GetScaledUInt16FloatValue 30 $scaleVAR ]\"
                        meterData_VARphC__var \"[ GetScaledUInt16FloatValue 31 $scaleVAR ]\"
                        meterData_PF__perct \"[ GetScaledUInt16FloatValue 33 $scalePF ]\"
                        meterData_PFphA__perct \"[ GetScaledUInt16FloatValue 34 $scalePF ]\"
                        meterData_PFphB__perct \"[ GetScaledUInt16FloatValue 35 $scalePF ]\"
                        meterData_PFphC__perct \"[ GetScaledUInt16FloatValue 36 $scalePF ]\"
                        meterData_TotWhExp__kWh \"[ GetScaledUInt32FloatValue 38 $scaleTotWh ]\"
                        meterData_TotWhExpPhA__kWh \"[ GetScaledUInt32FloatValue 40 $scaleTotWh ]\"
                        meterData_TotWhExpPhB__kWh \"[ GetScaledUInt32FloatValue 42 $scaleTotWh ]\"
                        meterData_TotWhExpPnC__kWh \"[ GetScaledUInt32FloatValue 44 $scaleTotWh ]\"
                        meterData_TotWhImp__kWh \"[ GetScaledUInt32FloatValue 46 $scaleTotWh ]\"
                        meterData_TotWhImpPhA__kWh \"[ GetScaledUInt32FloatValue 48 $scaleTotWh ]\"
                        meterData_TotWhImpPhB__kWh \"[ GetScaledUInt32FloatValue 50 $scaleTotWh ]\"
                        meterData_TotWhImpPnC__kWh \"[ GetScaledUInt32FloatValue 52 $scaleTotWh ]\"
                        meterData_Evt [ GetMeterErrorState 105 ]"

    # looks unsed in WattNode SE-WND-3Y-400-MB

    # scale \"[ GetScaleFactor 71 ]\"
    # puts "TotVAhExp    : $(GetScaledUInt32FloatValue 55 $scale ]\" VAh"
    # puts "TotVAhExpPhA : $(GetScaledUInt32FloatValue 57 $scale ]\" VAh"
    # puts "TotVAhExpPhB : $(GetScaledUInt32FloatValue 59 $scale ]\" VAh"
    # puts "TotVAhExpPnC : $(GetScaledUInt32FloatValue 61 $scale ]\" VAh"
    # puts "TotVAhImp    : $(GetScaledUInt32FloatValue 63 $scale ]\" VAh"
    # puts "TotVAhImpPhA : $(GetScaledUInt32FloatValue 65 $scale ]\" VAh"
    # puts "TotVAhImpPhB : $(GetScaledUInt32FloatValue 67 $scale ]\" VAh"
    # puts "TotVAhImpPhC : $(GetScaledUInt32FloatValue 69 $scale ]\" VAh"

    # scale \"[ GetScaleFactor 104 ]\"
    # puts "TotVArhImpQ1   : $(GetScaledUInt32FloatValue 72 $scale ]\" varh"
    # puts "TotVArhImpQ1PhA: $(GetScaledUInt32FloatValue 74 $scale ]\" varh"
    # puts "TotVArhImpQ1PhB: $(GetScaledUInt32FloatValue 76 $scale ]\" varh"
    # puts "TotVArhImpQ1PhC: $(GetScaledUInt32FloatValue 78 $scale ]\" varh"
    # puts "TotVArhImpQ2   : $(GetScaledUInt32FloatValue 80 $scale ]\" varh"
    # puts "TotVArhImpQ2PhA: $(GetScaledUInt32FloatValue 82 $scale ]\" varh"
    # puts "TotVArhImpQ2PhB: $(GetScaledUInt32FloatValue 84 $scale ]\" varh"
    # puts "TotVArhImpQ2PhC: $(GetScaledUInt32FloatValue 86 $scale ]\" varh"
    # puts "TotVArhExpQ3   : $(GetScaledUInt32FloatValue 88 $scale ]\" varh"
    # puts "TotVArhExpQ3PhA: $(GetScaledUInt32FloatValue 90 $scale ]\" varh"
    # puts "TotVArhExpQ3PhB: $(GetScaledUInt32FloatValue 92 $scale ]\" varh"
    # puts "TotVArhExpQ3PhC: $(GetScaledUInt32FloatValue 94 $scale ]\" varh"
    # puts "TotVArhExpQ4   : $(GetScaledUInt32FloatValue 96 $scale ]\" varh"
    # puts "TotVArhExpQ4PhA: $(GetScaledUInt32FloatValue 98 $scale ]\" varh"
    # puts "TotVArhExpQ4PhB: $(GetScaledUInt32FloatValue 100 $scale ]\" varh"
    # puts "TotVArhExpQ4PhC: $(GetScaledUInt32FloatValue 102 $scale ]\" varh"
        array set ::SE_modBus::dataArray $dataString
        if { $::SE_modBus::dataArray(meterData_ID) != 203 } {
            puts "meterData_ID : $::SE_modBus::dataArray(meterData_ID) (UNMATCHED - expected 203)"
            exit 1
        }
        if { $::SE_modBus::dataArray(meterData_L) != 105 } {
            puts "meterData_L  : $::SE_modBus::dataArray(meterData_L) (UNMATCHED - expected 105)"
            exit 1
        }
    }
}

foreach { item value } [ array get ::SE_modBus::dataArray ] {
    puts "$item=$value"
}

#END
