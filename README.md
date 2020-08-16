# eq3 / HomeMatic CCU-basierte Datenprotokollierung für SolarEdge-Wechselrichter mit ModBus-Zähler

[![License](http://img.shields.io/:license-lgpl3-blue.svg?style=flat)](http://www.gnu.org/licenses/lgpl-3.0.html) - außer modbus.tcl (MIT)

[english README.md](README.en.md)

Diese Software ist für unser privates PV-System mit einem SolarEdge SE5K-Wechselrichter in Kombination mit einem ModBus-basierten Zähler WattNode SE-WND-3Y-400-MB entwickelt.
Zähler und Wechselrichter kommunizieren dabei über einen separaten RS485-Bus, während der Wechselrichter zusätzlich mit dem LAN verbunden ist. Damit können über das ModBus-TCP-Protokoll viele Parameter sowohl vom Wechselrichter als auch vom Zähler ausgelesen werden (zur [Aktivierung von ModBus-TCP siehe unten](#Aktivierung-von-ModBus-TCP)).
SolarEdge implementiert (mehr oder weniger) die SunSpec-Spezifikation für diese Daten - siehe den Abschnitt [Links](#Links) unten.

Merkmale:

* Liest Mess- und Basisdaten von Wechselrichter und Zähler
* Niedriger CPU-Bedarf (insbesondere für CCU2..)
* Flexibel:
  * liest und liefert Daten für mehrere Blöcke in einem Skript-Aufruf
  * verschiedene Nutzungsmöglichkeiten in Shell-Skripten, HomeMatic Script (HMScript), JSON oder einfach formatiert "Menschen-lesbar"
  * Liest komplette oder reduzierte Datenblöcke
* Design soweit möglich offen für einfache Erweiterungen
  * z.B. ist die Liste der Ausgabevariablen leicht erweiterbar (es gibt - soweit eben möglich - keine feste Liste von Variablen)
  * Aufbau als Library

*Hinweis*: zur Einbindung in die CCU gibt es (aktuell) keine simple Installation - die Skripte sind nicht als Add-on zur Installation über die WebUI zusammengepackt. Auf die CCU muss man sie also selber z.B. per SSH / SCP bringen. Und die Einbindung in WebUI-Programme und Anlage von passenden Systemvariablen muss dem eigenen Bedarf nach gemacht werden - es gibt aber unter examples als Vorlage Skripte unserer Installation.  

## Zähler- und Wechselrichter-Kommunikation

```text
  +--------+           +------------+    +------------------+
  |        |           |            |    |                  |
  |  CCU2  |           |  Inverter  |    |  Wattnode-Meter  |
  |        |           |            |    |                  |
  +--------+           +------------+    +------------------+
       |                  |     |              |
       |      LAN         |     |   RS485      |
       +------------------+     +--------------+
```

## Zähler und Wechselrichter AC-Schema

```text
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

## Detaillierte Beschreibung

Mit diesen Skripten überwache ich die Daten beider Einheiten mit meiner eq3 / HomeMatic CCU2 (ja, dem alten Schätzchen ;-)). Das Lesen des ModBus erfolgt über Tcl-Skripte - die Basisbibliothek (modbus.tcl) stammt aus dem [homematic-forum.de](https://homematic-forum.de/forum/viewtopic.php?f=31&t=55722&p=553720). Die modbus_SE_reader_lib.tcl zum Lesen und Interpretieren der Daten und die modbus_SE_reader.tcl als (neue) Befehlszeilenschnittstelle sind dazu gekommen, die die Daten in einem einfach zu verwendenden Format zur Verwendung in HM-Skripten, Bash-Skripten, JSON oder "einfach nur lesbar" ausgibt.
Man kann wählen, ob man:

1. Allgemeine Daten wie das Modell, Seriennummern usw. vom Wechselrichter oder Zähler oder / und
2. Messungen vom Wechselrichter oder Zähler angezeigt haben möchte.

Für Bash und JSON werden die Daten in einem Array ausgegeben und zusätzlich werden noch die verwendeten Parameternamen in einer Liste angegeben. Für HM-Skripte erhalten die Ausgaben nur Name-Wert-Paare.

Bitte beachten: Mein SE5K verwendet das SunSpec-Mapping 103, den Zähler 203 - für dieses Mapping wird die modbus_SE_reader_lib.tcl geschrieben - plus ein oder zwei Besonderheiten des Wechselrichters (für mich sieht es so aus, als würde SE nicht 100% den Spezifikationen folgen). Wenn nötig, sollte das Skript offen genug sein, um weitere Typen abzubilden.

### Aufruf

```text
Das Skript modbus_SE_reader.tcl erfordert die Angabe von mindestens 4 Parametern.
(IP, Port, Funktion (Datenblock) und Ausgangstyp für das Auslesen von SolarEdge-Wechselrichter und Wattnode-Zähler.
Zum Beispiel: 192.168.178.35 502 Inverter SH

Die Ausgabe erfolgt in einer parse-baren Form für verschiedene Sprachen - JSON, HMSCRIPT oder SH ((bash-)shell)  
IP/FQDN DNS-Hostname oder IP-Adresse des SolarEdge-Wechselrichters
Port    Client-Port für ModBus TCP
Func    CommonInv    - Basis-Block des Wechselrichters lesen
        CommonMeter  - Basis-Block des Zählers lesen
        Inverter     - Teilmenge des Wechselrichter-Datenblocks lesen (SunSpec ID 103 mit SE-Änderungen...)
        Meter        - Teilmenge des Zählerdatenblocks lesen (SunSpec ID 203)
        InverterFull - Wechselrichter-Datenblock lesen, komplett (SunSpec ID 103 mit SE-Änderungen...)
        MeterFull    - Zählerdatenblock lesen (SunSpec ID 203)
 -> Func kann so oft wiederholt werden wie nötig, um direkt mehrere Blöcke zu lesen
Output  JSON         - Werte in JSON-Objekt plus Array mit Variablennamen ausgeben
        SH           - Ausgabewerte in baSH-parsebarer Form
        HMSCRIPT     - Ausgabewerte in HM-SCRIPT parsebarer Form
        HUMAN        - Output (einiger) Werte in formatierter Ansicht
```

Für die Skript-nutzbaren Ausgabe werden die Variablennamen nach folgendem Schema aufgebaut:

1. Abhängig von der Funktion:
   * inverterCData  OR
   * meterCData     OR
   * meterData      OR
   * inverterData
2. Plus:
   * "_" UND
   * Name des Feldes aus SunSpec
3. Plus:
   * "__" UND
   * Einheit

### Ausgabebeispiele

#### Formatierte Ausgabe

```text
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

#### HMSCRIPT-passend

```text
# modbus_SE_reader.tcl target 502 Meter HMSCRIPT
meterData_A__A=2.1|meterData_AphA__A=0.7|meterData_AphB__A=0.5|meterData_AphC__A=0.8|meterData_Evt=None|meterData_Hz__Hz=49.97|meterData_ID=203|meterData_L=105|meterData_PF__perct=57.51|meterData_PFphA__perct=86.26|meterData_PFphB__perct=23.04|meterData_PFphC__perct=63.23|meterData_PPV__V=-247.30|meterData_PVphC__V=235.72|meterData_PhV__V=235.22|meterData_PhVphAB__V=-247.56|meterData_PhVphA__V=235.22|meterData_PhVphBC__V=-246.88|meterData_PhVphB__V=235.86|meterData_PhVphCA__V=-247.46|meterData_TotWhExpPhA__kWh=-25.112|meterData_TotWhExpPhB__kWh=20.263|meterData_TotWhExpPnC__kWh=-20.459|meterData_TotWhExp__kWh=37.306|meterData_TotWhImpPhA__kWh=23.147|meterData_TotWhImpPhB__kWh=24.370|meterData_TotWhImpPnC__kWh=21.225|meterData_TotWhImp__kWh=65.822|meterData_VAR__var=-291|meterData_VARphA__var=-65|meterData_VARphB__var=-113|meterData_VARphC__var=-112|meterData_VA__VA=432|meterData_VAphA__VA=175|meterData_VAphB__VA=117|meterData_VAphC__VA=169|meterData_W__W=319|meterData_WphA__W=162|meterData_WphB__W=29|meterData_WphC__W=127|
```

Einfaches HM-Script-Muster (hier ohne Aufruf und nur Ausgabe per WriteLine)):

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

Bitte schauen Sie sich die zusätzlichen HM-Skripte im Ordner "examples" an - mit SolarPV_modbus_SE_aktuell.hms monitore ich die Basiswerte. Über CUxD-Highcharts ist es dann möglich, auch über die Zeit Auswertungen zu erstellen.

#### JSON

```text
# bin/modbus_SE_reader.tcl target 502 Inverter Meter JSON
{ "values" : {
   "inverterData_A__A" : 3.41,
   "inverterData_DCA__A" : 0.8961,
   "inverterData_DCV__V" : 746.5,
   "inverterData_DCW__W" : 669.0,
   "inverterData_Evt1" : "None",
   "inverterData_Hz__Hz" : 50.00,
   "inverterData_PPVphA__V" : 238.7,
   "inverterData_St" : "On (MPPT)",
   "inverterData_StVnd" : 0,
   "inverterData_TmpSnk__C" : 42.50,
   "inverterData_WH__kWh" : 295.933,
   "inverterData_W__W" : 659.0,
   "meterData_A__A" : 1.6,
   "meterData_Evt" : "None",
   "meterData_Hz__Hz" : 50.02,
   "meterData_PF__perct" : -21.02,
   "meterData_PhV__V" : 238.71,
   "meterData_TotWhExp__kWh" : 317.573,
   "meterData_TotWhImp__kWh" : 182.135,
   "meterData_VA__VA" : 721,
   "meterData_W__W" : 226},
{ "members" : ["inverterData_A__A","inverterData_DCA__A","inverterData_DCV__V","inverterData_DCW__W","inverterData_Evt1","inverterData_Hz__Hz","inverterData_PPVphA__V","inverterData_St","inverterData_StVnd","inverterData_TmpSnk__C","inverterData_WH__kWh","inverterData_W__W","meterData_A__A","meterData_Evt","meterData_Hz__Hz","meterData_PF__perct","meterData_PhV__V","meterData_TotWhExp__kWh","meterData_TotWhImp__kWh","meterData_VA__VA","meterData_W__W"] }
```

#### (BA)SH

```text
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

Benutzung in SH-Scripten so:

```SH
eval $(bin/modbus_SE_reader.tcl target 502 Meter SH)
```

#### Performance

Tcl ist auch auf der alten CCU2 schnell genug. Die reader_lib liest einen ganzen Datenblock in einer Anforderung, so dass es keinen großen Unterschied macht, ob ein oder zehn Werte geliefert werden sollen.  
Ausgabe von `time bin/modbus_SE_reader.tcl target 502 MeterFull HUMAN`:  
real    0m 0.27s  
user    0m 0.20s  
sys     0m 0.07s  
Da das Skript es erlaubt, mehrere Blöcke auf einmal zu lesen, wird der anfängliche Aufwand zum Starten der Tcl-Umgebung aus WebUI etc. reduziert. Die Verwendung von Meter / Inverter anstelle von MeterFull / InverterFull reduziert zusätzlich die CPU-Last ein wenig, wenn man keine speziellen Werte benötigt. Aufgrund des dynamischen Designs ist es kein Problem, bestimmte Werte in der Lese-Sektion (switch-Sektion) hinzuzufügen oder zu entfernen, Ausgangsänderungen erfolgen ohne Anpassung.

## Dank

* Dank an Indi55 von homematic-forum.de für das [Skript zum Lesen von ModBus TCP](https://homematic-forum.de/forum/viewtopic.php?f=31&t=55722&p=553720). Bitte beachten Sie seinen Dank an "Andrey-Nakin".

## Aktivierung von ModBus TCP

ModBus TCP kann in den Einstellungen des SE-Umrichters aktiviert werden. **Die Einstellung ist ohne Öffnen des Wechselrichters** erreichbar - einfach die Displaytaste unten am Gerät lang drücken und man gelangt in das Einstellungsmenü.
Um durch das Menü zu navigieren, gilt folgendes Schema: kurz drücken -> nächstes Menü oder Schaltoption, lang drücken -> Enter. Für die Navigation nach oben hat jede Menüebene einen speziellen Eintrag "Beenden".
Gehen Sie auf "Verbindung" und suchen Sie das Menü, um ModBus TCP zu aktivieren. Der Standard-Port war für mich 502, es scheint mir, das dieser nur über das "echte" Setup mit einem offenen Gerät geändert werden kann.
Ich habe einige Beiträge gelesen, in denen es hieß, daß man nicht zu lange auf die erste Verbindung warten sollte, sonst deaktiviert der Wechselrichter den ModBus TCP - ich hatte diese Probleme nicht.

## Links

* [SolarEdge Technical Note SunSpec-Implementation](https://www.solaredge.com/sites/default/files/sunspec-implementation-technical-note-de.pdf)
* [SunSpec Register Mapping](https://sunspec.org/wp-content/uploads/2019/10/SunSpecInformationModelReference20170928.xlsx)

### Andere SunSpec / SE-Monitoring-Lösungen

* [SunSpec-Monitor, Perl-based](https://github.com/tjko/sunspec-monitor)

### Referenzen

* [Tcl Reference Manual](http://tmml.sourceforge.net/doc/tcl/index.html)
* [Tcl/Tk Tutorial](https://www.tutorialspoint.com/tcl-tk/index.htm)
* [You might not need jQuery](http://youmightnotneedjquery.com/)
