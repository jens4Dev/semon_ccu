#!/bin/sh
#\
exec tclsh "$0" ${1+"$@"}

if { $argc != 6 } {
  puts ""
  puts "The modbus_interface.tcl script requires 6 numbers to be inputed."
  puts "(IP, Port, Device, Function, Register no, length of answer) for function read."
  puts "For example: 192.168.178.35 502 255 03 529 1"
  puts "or"
  puts "(IP, Port, Device, Function, Register no, Value) for function write."
  puts "For example: 192.168.178.35 502 255 06 529 45"
  puts " "
  puts "Port 	client Port"
  puts "Device  device number"
  puts "Fun		01 read coils"
  puts "		02 read discrete inputs"
  puts "		03 read holding registers"
  puts "	 	04 read input registers"
  puts "	 	05 write single coils"
  puts "		06 write single register"
  puts "		15 write multible coils"
  puts "		16 write multible registers"
  puts ""
  puts "Please try again."
  exit
}

# Modus TCP (allways!)

# Include Bibliothek
source /usr/local/addons/semon_ccu/modbus.tcl

# Send configuration
::modbus::configure -mode "TCP" -ip "[lindex $argv 0]" -port "[lindex $argv 1]"

# send parameters and receive answer
puts -nonewline [::modbus::cmd [lindex $argv 3] [lindex $argv 2] [lindex $argv 4] [lindex $argv 5]]

#END
