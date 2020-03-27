## eq3 / HomeMatic CCU based data logging for SolarEdge Inverters with Modbus Meter
This software was developed for our private PV device using a SolarEdge SE5K inverter in combination a with Modbus Meter WattNode SE-WND-3Y-400-MB. The meter is connected to the inverter via a separate RS485-bus. 
The inverter is connected to the LAN and with the ModBus TCP protocol you read lots of parameters from both the inverter as well as the meter. 

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
With this project I'm monitoring the data of both units with my eq3 / HomeMatic CCU2 (yeah, the old one ;-)). The data is read in short intervalls with a bash-based daemon and written to the data logs of CUxD. A couple of values are also written to system variables to be shown in the WebUI of the CCU and via XML-API / home24 app.
When you change the way of writing the data, it should be usable for other logging sinks too.
Why all Bash? Bash isn't very handy compared to other scripting language, yes. Understood more in tcl after finished pvread_funclib.sh - maybe doing more in tcl would have been the better approach.. And jens-maus created this nice deamon-bash. 

### Contributions
* Thanks to jens-maus for his great [hm_pdetect](https://github.com/jens-maus/hm_pdetect) - it's the base for the bash script and installation on the CCU...
* Thanks to Indi55 from homematic-forum.de for the [script to read from modbus TCP](https://homematic-forum.de/forum/viewtopic.php?f=31&t=55722&p=553720). Please note his cudos to "Andrey-Nakin".

### Activation of ModBus TCP
ModBus TCP can be activated in the settings of the SE inverter. **The setting is reachable without opening the inverter** - just press the display key long and you enter the settings. To navigate use the following scheme: short press -> next menu or switch option, long press -> enter. For the upward navigation each menu level has a special entry.
Go to connection and find the menu to enable ModBus TCP. Default port for me was 502, seems as this can only be changed by using the "real" setup with an open device.
I read some posts stating that you should not wait to long for the first connect otherwise the inverter will disable the ModBus TCP - I didn't had that trouble.

### Mappings
My SE5K is using SunSpec mapping 103, the meter 203.

### Issues
* modbus-scripts depends on hard coded path /usr/local/addons/modbus/

### Links
* [https://www.solaredge.com/sites/default/files/sunspec-implementation-technical-note-de.pdf](SolarEdge Technical Note SunSpec-Implementation)
* [https://sunspec.org/wp-content/uploads/2019/10/SunSpecInformationModelReference20170928.xlsx](SunSpec Register Mapping)

#### Other SunSpec / SE-Monitoring Solutions
* [https://github.com/tjko/sunspec-monitor](SunSpec-Monitor), Perl-based

CCU2 with discrete var:
real    0m 17.72s
user    0m 3.59s
sys     0m 5.78s

CCU2 with ANSI & some (()) for if:
real    0m 14.21s
user    0m 3.47s
sys     0m 6.10s