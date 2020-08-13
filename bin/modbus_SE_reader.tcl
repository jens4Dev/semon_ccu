#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

# 
# (c) jensDev - license LGPL3
#

if { $argc < 4 } {
  puts ""
  puts "The modbus_SE_reader.tcl script requires at least 4 parameters to be given."
  puts "(IP, Port, Function (Data-Block) and output-type for reading SolarEdge Inverter and Wattnode Meter."
  puts "For example: 192.168.178.35 502 Inverter SH"
  puts " "
  puts "Output comes in a parseable form for different languages - JSON, HMSCRIPT or SH ((bash-)shell)  "
  puts "IP/FQDN DNS-hostname or IP-adress of SolarEdge Inverter"
  puts "Port 	client port for ModBus TCP"
  puts "Func 	CommonInv    - read Inverter common block"
  puts "     	CommonMeter  - read Meter common block"
  puts "        Inverter     - read subset of Inverter data block (SunSpec ID 103 with SE-changes..)"
  puts "        Meter        - read subset of Meter data block (SunSpec ID 203)"
  puts "        InverterFull - read Iverter data block (SunSpec ID 103 with SE-changes..)"
  puts "        MeterFull    - read Meter data block (SunSpec ID 203)"
  puts " -> Func can be repeated as much as neccessary to read multiple block at once"
  puts "Output  JSON         - Output values in JSON-object plus array with member names"
  puts "        SH           - Output values in baSH-parseable form"
  puts "        HMSCRIPT     - Output values in HM-SCRIPT parseable form"
  puts "        HUMAN        - Output (some) values in human friendly view"
  puts "Please try again."
  exit 1
}

# access object-members in JSON:
# valuesMeter[membersMeter[0]]

# use output for baSH-script:
# eval $(bin/modbus_SE_reader.tcl target 502 Meter SH)

# use in HMSCRIPT
#string daten="meterData_A__A=2.4|meterData_AphA__A=1.1|meterData_AphB__A=0.4|";
#string tuple;
#foreach(tuple, data.Split("|")) 
#{
#   string item = tuple.StrValueByIndex("=", 0);
#   string value = tuple.StrValueByIndex("=", 1);
#   WriteLine(item#" "#value);
#}


# Include lib - must in same dir as this script
set script_path [ file dirname [ info script ] ]
source $script_path/modbus.tcl
source $script_path/modbus_SE_lib.tcl

Read_SE_ModBus $argv