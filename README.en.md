## eq3 / HomeMatic CCU based data logging for SolarEdge Inverters with ModBus Meter
[![License](http://img.shields.io/:license-lgpl3-blue.svg?style=flat)](http://www.gnu.org/licenses/lgpl-3.0.html)

This software was developed for our private PV-device using a SolarEdge SE5K inverter in combination a with ModBus-based meter WattNode SE-WND-3Y-400-MB. 
Meter and inverter are talking via a separate RS485-bus while the inverter is also connected to the LAN. Its ModBus TCP protocol allows you to read lots of parameters from both the inverter as well as the meter (for [activation of ModBus TCP see below](#Activation-of-ModBus-TCP)).
SolarEdge implements (more or less) the SunSpec-Specification for this data - see the [links](#Links) section below.

Features:
* Reads measurements and command data from inverter and meter
* Flexible: reads data & deliver data for multiple blocks in one call
* Multi-purpose: Interfaces to different use cases like Shell-scripts, HomeMatic Script (HMScript), JSON or just human readable
* Reads full or reduced data blocks
* Open for extension, e.g. list of output variables is easily extendable (no fixed list of variables as far as possible) 
* Low CPU-footprint (especially for CCU2..)

### Meter and Inverter Communication
```
  +--------+           +------------+    +------------------+
  |        |           |            |    |                  |
  |  CCU2  |           |  Inverter  |    |  Wattnode-Meter  |
  |        |           |            |    |                  |
  +--------+           +------------+    +------------------+
       |                  |     |              |
       |      LAN         |     |   RS485      |
       +------------------+     +--------------+
```

### Meter and Inverter AC-schema
```
                                                                              XX
                          +----------------+                                 XXXX
                          |                |                                XX  XX
+---------------+         |    Consumer    |     +------------------+     XX Grid XX
|               |         |                |     |                  |          +
|               |         +-------+--------+     |                  | V        |
|   Inverter    |                 |          +---+  Wattnode-Meter  +--+       |
|               |                 |          | A |                  |  |       |
|               |                 |          |   |                  |  |       |
+-------+-------+                 |          |   +------------------+  |       |
        |                         |          |                         |       |
        |                         |          |                         |       |
        |                         |        +---+                       |       |
        +-------------------------+------------------------------------+-------+
                                           +---+
                                          CT-Sensor
```

### Detailed description
With this scripts I'm monitoring the data of both units with my eq3 / HomeMatic CCU2 (yeah, the old one ;-)). Reading the ModBus is done via Tcl-scripts - the base library (modbus.tcl) is from [homematic-forum.de](https://homematic-forum.de/forum/viewtopic.php?f=31&t=55722&p=553720). I added the modbus_SE_reader_lib.tcl to read and interpret the data and the modbus_SE_reader.tcl as a (new) command-line interface, which outputs the data in an easy to use format for usage in HM-scripts, Bash-scripts, JSON or just for human beings. 
You can choose whether you want to read
1. Common data like the model, serial numbers, etc. from inverter or meter or / and
2. Measurements from inverter or meter.

For Bash and JSON the data is printed in an array and additionally the used parameters names are given in list. For HM-scripts you only get name-value pairs.

Please note: My SE5K is using SunSpec mapping 103, the meter 203 - for this mapping the modbus_SE_reader_lib.tcl is written - plus one or two specifics of the inverter (for me it looks like not 100% following the specs). If necessary it should be open enough to map more types.

#### Invocation
```
The modbus_SE_reader.tcl script requires at least 4 parameters to be given.
(IP, Port, Function (Data-Block) and output-type for reading SolarEdge Inverter and Wattnode Meter.
For example: 192.168.178.35 502 Inverter SH
 
Output comes in a parseable form for different languages - JSON, HMSCRIPT or SH ((bash-)shell)  
IP/FQDN DNS-hostname or IP-adress of SolarEdge Inverter
Port    client port for ModBus TCP
Func    CommonInv    - read Inverter common block
        CommonMeter  - read Meter common block
        Inverter     - read subset of Inverter data block (SunSpec ID 103 with SE-changes..)
        Meter        - read subset of Meter data block (SunSpec ID 203)
        InverterFull - read Iverter data block (SunSpec ID 103 with SE-changes..)
        MeterFull    - read Meter data block (SunSpec ID 203)
 -> Func can be repeated as much as neccessary to read multiple block at once
Output  JSON         - Output values in JSON-object plus array with member names
        SH           - Output values in baSH-parseable form
        HMSCRIPT     - Output values in HM-SCRIPT parseable form
        HUMAN        - Output (some) values in human friendly view
```
For the computable output the variable names were build in the following scheme:
1. Depending on the function:
   * inverterCData  OR
   * meterCData     OR
   * meterData      OR
   * inverterData
2. Plus:
   * "_" AND
   * Name of field from SunSpec
3. Plus:
   * "__" AND
   * Unit 

#### Output samples
##### Human readable
```
# modbus_SE_reader.tcl target 502 Meter HUMAN

METER:

   Exported Energy:       65.822 kWh
   Imported Energy:       34.891 kWh
        Real Power:          440 W
    Apparent Power:          534 VA
      Power Factor:       57.860 %
      Voltage (AC):       235.29 V (49.98 Hz)
      Current (AC):         2.70 A
```
##### HMSCRIPT-friendly
```
# modbus_SE_reader.tcl target 502 Meter HMSCRIPT
meterData_A__A=2.1|meterData_AphA__A=0.7|meterData_AphB__A=0.5|meterData_AphC__A=0.8|meterData_Evt=None|meterData_Hz__Hz=49.97|meterData_ID=203|meterData_L=105|meterData_PF__perct=57.51|meterData_PFphA__perct=86.26|meterData_PFphB__perct=23.04|meterData_PFphC__perct=63.23|meterData_PPV__V=-247.30|meterData_PVphC__V=235.72|meterData_PhV__V=235.22|meterData_PhVphAB__V=-247.56|meterData_PhVphA__V=235.22|meterData_PhVphBC__V=-246.88|meterData_PhVphB__V=235.86|meterData_PhVphCA__V=-247.46|meterData_TotWhExpPhA__kWh=-25.112|meterData_TotWhExpPhB__kWh=20.263|meterData_TotWhExpPnC__kWh=-20.459|meterData_TotWhExp__kWh=37.306|meterData_TotWhImpPhA__kWh=23.147|meterData_TotWhImpPhB__kWh=24.370|meterData_TotWhImpPnC__kWh=21.225|meterData_TotWhImp__kWh=65.822|meterData_VAR__var=-291|meterData_VARphA__var=-65|meterData_VARphB__var=-113|meterData_VARphC__var=-112|meterData_VA__VA=432|meterData_VAphA__VA=175|meterData_VAphB__VA=117|meterData_VAphC__VA=169|meterData_W__W=319|meterData_WphA__W=162|meterData_WphB__W=29|meterData_WphC__W=127|
```
Simple HM-Script to use the data (just print..):
```javascript
string daten="meterData_A__A=2.4|meterData_AphA__A=1.1|meterData_AphB__A=0.4|";
string tuple;
foreach(tuple, data.Split("|")) 
{
   string item = tuple.StrValueByIndex("=", 0);
   string value = tuple.StrValueByIndex("=", 1);
   WriteLine(item#" "#value);
}
```
Please look at the additional HM-Scripts in folder "examples" - with SolarPV_modbus_SE_aktuell.hms I'm tracking the base values. Via CUxD-Highcharts it's possible to evaluate over the time.
##### JSON
```
# bin/modbus_SE_reader.tcl target 502 MeterFull JSON
values={
   "meterData_A__A" : 2.0,
   "meterData_AphA__A" : 0.6,
   "meterData_AphB__A" : 0.5,
   "meterData_AphC__A" : 0.7,
   "meterData_Evt" : "None",
   "meterData_Hz__Hz" : 49.97,
   "meterData_ID" : 203,
   "meterData_L" : 105,
   "meterData_PF__perct" : 56.18,
   "meterData_PFphA__perct" : 83.72,
   "meterData_PFphB__perct" : 22.48,
   "meterData_PFphC__perct" : 62.35,
   "meterData_PPV__V" : -248.67,
   "meterData_PVphC__V" : 234.60,
   "meterData_PhV__V" : 234.67,
   "meterData_PhVphAB__V" : -248.13,
   "meterData_PhVphA__V" : 234.67,
   "meterData_PhVphBC__V" : -248.96,
   "meterData_PhVphB__V" : 235.17,
   "meterData_PhVphCA__V" : -248.91,
   "meterData_TotWhExpPhA__kWh" : -25.053,
   "meterData_TotWhExpPhB__kWh" : 20.274,
   "meterData_TotWhExpPnC__kWh" : -20.404,
   "meterData_TotWhExp__kWh" : 37.432,
   "meterData_TotWhImpPhA__kWh" : 23.147,
   "meterData_TotWhImpPhB__kWh" : 24.370,
   "meterData_TotWhImpPnC__kWh" : 21.225,
   "meterData_TotWhImp__kWh" : 65.822,
   "meterData_VAR__var" : -280,
   "meterData_VARphA__var" : -62,
   "meterData_VARphB__var" : -113,
   "meterData_VARphC__var" : -104,
   "meterData_VA__VA" : 393,
   "meterData_VAphA__VA" : 147,
   "meterData_VAphB__VA" : 116,
   "meterData_VAphC__VA" : 154,
   "meterData_W__W" : 275,
   "meterData_WphA__W" : 133,
   "meterData_WphB__W" : 28,
   "meterData_WphC__W" : 113}
members=["meterData_A__A","meterData_AphA__A","meterData_AphB__A","meterData_AphC__A","meterData_Evt","meterData_Hz__Hz","meterData_ID","meterData_L","meterData_PF__perct","meterData_PFphA__perct","meterData_PFphB__perct","meterData_PFphC__perct","meterData_PPV__V","meterData_PVphC__V","meterData_PhV__V","meterData_PhVphAB__V","meterData_PhVphA__V","meterData_PhVphBC__V","meterData_PhVphB__V","meterData_PhVphCA__V","meterData_TotWhExpPhA__kWh","meterData_TotWhExpPhB__kWh","meterData_TotWhExpPnC__kWh","meterData_TotWhExp__kWh","meterData_TotWhImpPhA__kWh","meterData_TotWhImpPhB__kWh","meterData_TotWhImpPnC__kWh","meterData_TotWhImp__kWh","meterData_VAR__var","meterData_VARphA__var","meterData_VARphB__var","meterData_VARphC__var","meterData_VA__VA","meterData_VAphA__VA","meterData_VAphB__VA","meterData_VAphC__VA","meterData_W__W","meterData_WphA__W","meterData_WphB__W","meterData_WphC__W"]
```
##### (BA)SH
```
# bin/modbus_SE_reader.tcl target 502 Meter Inverter SH
inverterData_A__A=0
inverterData_DCA__A=0
inverterData_DCV__V=15.2
inverterData_DCW__W=0
inverterData_Evt1=None
inverterData_Hz__Hz=50.02
inverterData_PPVphA__V=234.9
inverterData_St=Off
inverterData_StVnd=0
inverterData_TmpSnk__C=29.50
inverterData_WH__kWh=0
inverterData_W__W=0
meterData_A__A=2.2
meterData_Evt=None
meterData_Hz__Hz=50.02
meterData_PF__perct=41.93
meterData_PhV__V=235.09
meterData_TotWhExp__kWh=86.270
meterData_TotWhImp__kWh=138.174
meterData_VA__VA=441
meterData_W__W=-220
variables='inverterData_A__A inverterData_DCA__A inverterData_DCV__V inverterData_DCW__W inverterData_Evt1 inverterData_Hz__Hz inverterData_PPVphA__V inverterData_St inverterData_StVnd inverterData_TmpSnk__C inverterData_WH__kWh inverterData_W__W meterData_A__A meterData_Evt meterData_Hz__Hz meterData_PF__perct meterData_PhV__V meterData_TotWhExp__kWh meterData_TotWhImp__kWh meterData_VA__VA meterData_W__W'
```
Usage in SH-scripts with:
```SH
eval $(bin/modbus_SE_reader.tcl target 502 Meter SH)
```
#### Performance
Tcl is fast enough also on the old CCU2. The reader_lib also reads a data block in one request, this way it is not a big difference whether you want one or ten values. 
Sample of `time bin/modbus_SE_reader.tcl target 502 MeterFull HUMAN`:  
real    0m 0.27s  
user    0m 0.20s  
sys     0m 0.07s  
Because the script allows to read multiple blocks at once the initial effort to start the Tcl-environment from WebUI etc. is reduced. Using Meter / Inverter instead of MeterFull / InverterFull also reduces load a bit if you don't need special values (due to the dynamic design, it's not a problem to add or remove specific values in the reading-section (switch), output changes w/o adaption).

### Thanks
* Thanks to Indi55 from homematic-forum.de for the [script to read from ModBus TCP](https://homematic-forum.de/forum/viewtopic.php?f=31&t=55722&p=553720). Please note his cudos to "Andrey-Nakin".

### Activation of ModBus TCP
ModBus TCP can be activated in the settings of the SE inverter. **The setting is reachable without opening the inverter** - just press the display key long and you enter the settings menu. 
To navigate their use the following scheme: short press -> next menu or switch option, long press -> enter. For the upward navigation each menu level has a special entry.
Go to connection and find the menu to enable ModBus TCP. Default port for me was 502, seems as this can only be changed by using the "real" setup with an open device.
I read some posts stating that you should not wait to long for the first connect otherwise the inverter will disable the ModBus TCP - I didn't had that trouble.

### Links
* [SolarEdge Technical Note SunSpec-Implementation](https://www.solaredge.com/sites/default/files/sunspec-implementation-technical-note-de.pdf)
* [SunSpec Register Mapping](https://sunspec.org/wp-content/uploads/2019/10/SunSpecInformationModelReference20170928.xlsx)

#### Other SunSpec / SE-Monitoring Solutions
* [SunSpec-Monitor, Perl-based](https://github.com/tjko/sunspec-monitor)

### Tcl Reference (just for the author's first steps in Tcl...)
* [Tcl Reference Manual](http://tmml.sourceforge.net/doc/tcl/index.html)
* [Tcl/Tk Tutorial](https://www.tutorialspoint.com/tcl-tk/index.htm)