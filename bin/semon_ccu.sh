#!/usr/bin/env bash
#
# Based on the script for hm_pdetect at https://github.com/jens-maus/hm_pdetect
#

VERSION="0.1"
VERSION_DATE="Mar 26 2020"

DECSEPERATOR=.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#####################################################
# Main script starts here, dont modify from here on

# before we read in default values we have to find
# out which SE_* variables the user might have specified
# on the command-line himself
USERVARS=$(set -o posix; set | grep "SE_.*=" 2>/dev/null)

# IP addresses/hostnames of SolarEdge Inverter 
SE_INVERTER_IP=${SE_INVERTER_IP:-"target"}
# Port-Number ModBus TCP
SE_INVERTER_MODBUS_PORT=${SE_INVERTER_MODBUS_PORT:-"502"}

# IP address/hostname of CCU2
SE_CCU_IP=${SE_CCU_IP:-"homematic-ccu2"}

# Port settings for ReGa communications
SE_CCU_REGAPORT=${SE_CCU_REGAPORT:-"8181"}

# number of minutes to wait between iterations
# (will run semon_ccu in an endless loop)
SE_INTERVAL_TIME=${SE_INTERVAL_TIME:-}

# maximum number of iterations if running in interval mode
# (default: 0=unlimited)
SE_INTERVAL_MAX=${SE_INTERVAL_MAX:-0}

# List of values to log via CuXD.LOGIT: [text for CuXD]=name_of_var_in_script
SE_LOGIT_VARS=${SE_LOGIT_VARS:-"([WR_Leistung_W]=inverterData_W [ME_Wh_export]=meterData_TotWhExp)"}

# Name of the CCU variable prefix used
SE_CCU_PV_VAR=${SE_CCU_PV_VAR:-"SolarPV.SV_"}

# Mapping of CCU variables updated - SE_CCU_PV_VAR is put in front of each variable
SE_CCU_VARS=${SE_CCU_VARS:-"([WR_Leistung_W]=inverterData_W [ME_Wh_export]=meterData_TotWhExp)"}

# Level of variables read via ModBus
SM_READ_FULL_DATA=${SM_READ_FULL_DATA:-false}

# Read device status
SM_READ_STATUS=${SM_READ_STATUS:-true}

# where to save the process ID in case hm_pdetect runs as
# a daemon
SE_DAEMON_PIDFILE=${SE_DAEMON_PIDFILE:-"/var/run/semon_ccu.pid"}

# Processing logfile output name
# (default: no output)
SE_PROCESSLOG_FILE=${SE_PROCESSLOG_FILE:-"/var/log/semon_ccu.log"}

# maximum number of lines the logfile should contain
# (default: 500 lines)
SE_PROCESSLOG_MAXLINES=${SE_PROCESSLOG_MAXLINES:-500}

# the config file path
# (default: 'semon_ccu.conf' in path where semon_ccu.sh script resists)
CONFIG_FILE=${CONFIG_FILE:-"$(cd "${0%/*}"; pwd)/semon_ccu.conf"}

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0

###############################
# now we check all dependencies first. That means we
# check that we have the right bash version and third-party tools
# installed

# bash check
if [[ $(echo ${BASH_VERSION} | cut -d. -f1) -lt 4 ]]; then
  echo "ERROR: this script requires a bash shell of version 4 or higher. Please install."
  exit ${RETURN_FAILURE}
fi

# wget check
if [[ ! -x $(which wget) ]]; then
  echo "ERROR: 'wget' tool missing. Please install."
  exit ${RETURN_FAILURE}
fi

# declare all associative arrays first (bash v4+ required)
declare -A HM_USER_LIST     # username<>MAC/IP tuple

###############################
# lets check if config file was specified as a cmdline arg
if [[ ${#} -gt 0        && \
      ${!#} != "child"  && \
      ${!#} != "daemon" && \
      ${!#} != "start"  && \
      ${!#} != "stop" ]]; then
  CONFIG_FILE="${!#}"
fi

if [[ ! -e ${CONFIG_FILE} ]]; then
  echo "WARNING: config file '${CONFIG_FILE}' doesn't exist. Using default values."
  CONFIG_FILE=
fi

# lets source the config file a first time
if [[ -n ${CONFIG_FILE} ]]; then
  source "${CONFIG_FILE}"
  if [[ $? -ne 0 ]]; then
    echo "ERROR: couldn't source config file '${CONFIG_FILE}'. Please check config file syntax."
    exit ${RETURN_FAILURE}
  fi

  # lets eval the user overridden variables
  # so that they take priority
  eval ${USERVARS}
fi

###############################
# run semon_ccu as a real daemon by using setsid
# to fork and deattach it from a terminal.
PROCESS_MODE=normal
if [[ ${#} -gt 0 ]]; then
  FILE=${0##*/}
  DIR=$(cd "${0%/*}"; pwd)

  # lets check the supplied command
  case "${1}" in

    start) # 1. lets start the child
      shift
      exec "${DIR}/${FILE}" child "${CONFIG_FILE}" &
      exit 0
    ;;

    child) # 2. We are the child. We need to fork the daemon now
      shift
      umask 0
      echo
      echo "Starting semon_ccu in daemon mode."
      exec setsid ${DIR}/${FILE} daemon "${CONFIG_FILE}" </dev/null >/dev/null 2>/dev/null &
      exit 0
    ;;

    daemon) # 3. We are the daemon. Lets continue with the real stuff
      shift
      # save the PID number in the specified PIDFILE so that we 
      # can kill it later on using this file
      if [[ -n ${SE_DAEMON_PIDFILE} ]]; then
        echo $$ >${SE_DAEMON_PIDFILE}
      fi

      # if we end up here we are in daemon mode and
      # can continue normally but make sure we dont allow any
      # input
      exec 0</dev/null

      # make sure PROCESS_MODE is set to daemon
      PROCESS_MODE=daemon
    ;;

    stop) # 4. stop the daemon if requested
      if [[ -f ${SE_DAEMON_PIDFILE} ]]; then
        echo "Stopping semon_ccu (pid: $(cat ${SE_DAEMON_PIDFILE}))"
        kill $(cat ${SE_DAEMON_PIDFILE}) >/dev/null 2>&1
        rm -f ${SE_DAEMON_PIDFILE} >/dev/null 2>&1
      fi
      exit 0
    ;;

  esac
fi

###############################
# read PV data from SolarEdge Inverter & WattNode Meter
source "pvread_funclib.sh"

###############################
# function returning the current state of a homematic variable
# and returning success/failure if the variable was found/not
function getVariableState()
{
  local name="$1"

  local result=$(wget -q -O - "http://${SE_CCU_IP}:${SE_CCU_REGAPORT}/rega.exe?state=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${name}').Value()")
  if [[ ${result} =~ \<state\>(.*)\</state\> ]]; then
    result="${BASH_REMATCH[1]}"
    if [[ ${result} != "null" ]]; then
      echo ${result}
      return ${RETURN_SUCCESS}
    fi
  fi

  echo ${result}
  return ${RETURN_FAILURE}
}

# function setting the state of a homematic variable in case it
# it different to the current state and the variable exists
function setVariableState()
{
  local name="$1"
  local newstate="$2"

  # before we going to set the variable state we
  # query the current state and if the variable exists or not
  curstate=$(getVariableState "${name}")
  if [[ ${curstate} == "null" ]]; then
    return ${RETURN_FAILURE}
  fi

  # only continue if the current state is different to the new state
  if [[ ${curstate} == ${newstate//\'} ]]; then
    return ${RETURN_SUCCESS}
  fi

  # the variable should be set to a new state, so lets do it
  echo -n "  Setting CCU variable '${name}': '${newstate//\'}'... "
  local result=$(wget -q -O - "http://${SE_CCU_IP}:${SE_CCU_REGAPORT}/rega.exe?state=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${name}').State(${newstate})")
  if [[ ${result} =~ \<state\>(.*)\</state\> ]]; then
    result="${BASH_REMATCH[1]}"
  else
    result=""
  fi

  # if setting the variable succeeded the result will be always
  # 'true'
  if [[ ${result} == "true" ]]; then
    echo "ok."
    return ${RETURN_SUCCESS}
  fi

  echo "ERROR."
  return ${RETURN_FAILURE}
}

# function to check if a certain boolean system variable exists
# at a CCU and if not creates it accordingly
function createVariable()
{
  local vaname=$1
  local vatype=$2
  local comment=$3
  local valist=$4

  # first we find out if the variable already exists and if
  # the value name/list it contains matches the value name/list
  # we are expecting
  local postbody=""
  if [[ ${vatype} == "enum" ]]; then
    local result=$(wget -q -O - "http://${SE_CCU_IP}:${SE_CCU_REGAPORT}/rega.exe?valueList=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${vaname}').ValueList()")
    if [[ ${result} =~ \<valueList\>(.*)\</valueList\> ]]; then
      result="${BASH_REMATCH[1]}"
    fi

    # make sure result is not empty and not null
    if [[ -n ${result} && ${result} != "null" ]]; then
      if [[ ${result} != ${valist} ]]; then
        echo -n "  Modifying CCU variable '${vaname}' (${vatype})... "
        postbody="string v='${vaname}';dom.GetObject(ID_SYSTEM_VARIABLES).Get(v).ValueList('${valist}')"
      fi
    else
      echo -n "  Creating CCU variable '${vaname}' (${vatype})... "
      postbody="string v='${vaname}';boolean f=true;string i;foreach(i,dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()){if(v==dom.GetObject(i).Name()){f=false;}};if(f){object s=dom.GetObject(ID_SYSTEM_VARIABLES);object n=dom.CreateObject(OT_VARDP);n.Name(v);s.Add(n.ID());n.ValueType(ivtInteger);n.ValueSubType(istEnum);n.DPInfo('${comment}');n.ValueList('${valist}');n.State(0);dom.RTUpdate(false);}"
    fi
  elif [[ ${vatype} == "string" ]]; then
    getVariableState "${vaname}" >/dev/null
    if [[ $? -eq 1 ]]; then
      echo -n "  Creating CCU variable '${vaname}' (${vatype})... "
      postbody="string v='${vaname}';boolean f=true;string i;foreach(i,dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()){if(v==dom.GetObject(i).Name()){f=false;}};if(f){object s=dom.GetObject(ID_SYSTEM_VARIABLES);object n=dom.CreateObject(OT_VARDP);n.Name(v);s.Add(n.ID());n.ValueType(ivtString);n.ValueSubType(istChar8859);n.DPInfo('${comment}');n.State('');dom.RTUpdate(false);}"
    fi
  else # vatype == Bool - fixed "true" / "false" as values for true / false
    local result=$(wget -q -O - "http://${SE_CCU_IP}:${SE_CCU_REGAPORT}/rega.exe?valueName0=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${vaname}').ValueName0()&valueName1=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${vaname}').ValueName1()")
    local valueName0="null"
    local valueName1="null"

    local boolTRUE="true"
    local boolFALSE="false"

    if [[ ${result} =~ \<valueName0\>(.*)\</valueName0\>\<valueName1\>(.*)\</valueName1\> ]]; then
      valueName0="${BASH_REMATCH[1]}"
      valueName1="${BASH_REMATCH[2]}"
    fi

    # make sure result is not empty and not null
    if [[ -n ${result} && \
          ${valueName0} != "null" && ${valueName1} != "null" ]]; then

       if [[ ${valueName0} != ${boolFALSE} || \
             ${valueName1} != ${boolTRUE} ]]; then
         echo -n "  Modifying CCU variable '${vaname}' (${vatype})... "
         postbody="string v='${vaname}';dom.GetObject(ID_SYSTEM_VARIABLES).Get(v).ValueName0('${boolFALSE}');dom.GetObject(ID_SYSTEM_VARIABLES).Get(v).ValueName1('${boolTRUE}')"
       fi
    else
      echo -n "  Creating CCU variable '${vaname}' (${vatype})... "
      postbody="string v='${vaname}';boolean f=true;string i;foreach(i,dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()){if(v==dom.GetObject(i).Name()){f=false;}};if(f){object s=dom.GetObject(ID_SYSTEM_VARIABLES);object n=dom.CreateObject(OT_VARDP);n.Name(v);s.Add(n.ID());n.ValueType(ivtBinary);n.ValueSubType(istBool);n.DPInfo('${comment}');n.ValueName1('${boolTRUE}');n.ValueName0('${boolFALSE}');n.State(false);dom.RTUpdate(false);}"
    fi
  fi

  # if postbody is empty there is nothing to do
  # and the variable exists with correct value name/list
  if [[ -z ${postbody} ]]; then
    return ${RETURN_SUCCESS}
  fi

  # use wget to post the tcl script to tclrega.exe
  local result=$(wget -q -O - --post-data "${postbody}" "http://${SE_CCU_IP}:${SE_CCU_REGAPORT}/tclrega.exe")
  if [[ ${result} =~ \<v\>${vaname}\</v\> ]]; then
    echo "ok."
    return ${RETURN_SUCCESS}
  else
    echo "ERROR: could not create system variable '${vaname}'."
    return ${RETURN_FAILURE}
  fi
}

# last iteration didn't work out so lets

# function to count the position within the enum list
# where the presence list matches
function whichEnumID()
{
  local enumList="$1"
  local presenceList="$2"

  # now we iterate through the ;—separated enumList
  IFS=';'
  local i=0
  local result=0
  for id in ${enumList}; do
    if [[ ${presenceList} == ${id} ]]; then
      result=$i
      break
    fi
    ((i = i + 1 ))
  done
  IFS=' '

  echo ${result}
}

function ProcessCommonData() {
  echo "Found Inverter:"
  echo " ID : $inverterData_ID"
  echo " DID: $inverterData_DID"
  echo " L  : $inverterData_L"
  echo " Mn : $inverterData_Mn"
  echo " Md : $inverterData_Md"
  echo " Opt: $inverterData_Opt"
  echo " Vr : $inverterData_Vr"
  echo " SN : $inverterData_SN"
  echo " DA : $inverterData_DA"

  echo "Found Meter:"
  echo " ID : $meterData_ID"
  echo " L  : $meterData_L"
  echo " Mn : $meterData_Mn"
  echo " Md : $meterData_Md"
  echo " Opt: $meterData_Opt"
  echo " Vr : $meterData_Vr"
  echo " SN : $meterData_SN"
  echo " DA : $meterData_DA"
}

function ProcessGeneralStatus() {
  echo "Status Inverter:"
  echo " TmpSnk      : $inverterData_TmpSnk"
  echo " St          : $inverterData_St"
  echo " StVnd       : $inverterData_StVnd"
  echo " Evt1        : $inverterData_Evt1"
  echo "Status Meter:"
  echo " Evt         : $meterData_Evt"
}

function ProcessBaseData() {
  echo "Measurements Inverter:"
  echo " A          : $inverterData_A"
  echo " AphA       : $inverterData_AphA"
  echo " AphB       : $inverterData_AphB"
  echo " AphC       : $inverterData_AphC"
  echo " W          : $inverterData_W"
  echo " WH         : $inverterData_WH"
  echo " DCA        : $inverterData_DCA"
  echo " DCV        : $inverterData_DCV"
  echo " DCW        : $inverterData_DCW"
  echo "Measurements Meter:"
  echo " A          : $meterData_A"
  echo " PhV        : $meterData_PhV"
  echo " W          : $meterData_W"
  echo " WphA       : $meterData_WphA"
  echo " WphB       : $meterData_WphB"
  echo " WphC       : $meterData_WphC"
  echo " TotWhExp   : $meterData_TotWhExp"
  echo " TotWhExpPhA: $meterData_TotWhExpPhA"
  echo " TotWhExpPhB: $meterData_TotWhExpPhB"
  echo " TotWhExpPnC: $meterData_TotWhExpPnC"
  echo " TotWhImp   : $meterData_TotWhImp"
  echo " TotWhImpPhA: $meterData_TotWhImpPhA"
  echo " TotWhImpPhB: $meterData_TotWhImpPhB"
  echo " TotWhImpPnC: $meterData_TotWhImpPnC"
}

function ProcessFullData() {
  echo "Measurements Inverter:"
  echo " A          : $inverterData_A"
  echo " AphA       : $inverterData_AphA"
  echo " AphB       : $inverterData_AphB"
  echo " AphC       : $inverterData_AphC"
  echo " PPVphAB    : $inverterData_PPVphAB"
  echo " PPVphBC    : $inverterData_PPVphBC"
  echo " PPVphCA    : $inverterData_PPVphCA"
  echo " PPVphA     : $inverterData_PPVphA"
  echo " PPVphB     : $inverterData_PPVphB"
  echo " PPVphC     : $inverterData_PPVphC"
  echo " W          : $inverterData_W"
  echo " Hz         : $inverterData_Hz"
  echo " VA         : $inverterData_VA"
  echo " VAr        : $inverterData_VAr"
  echo " PF         : $inverterData_PF"
  echo " WH         : $inverterData_WH"
  echo " DCA        : $inverterData_DCA"
  echo " DCV        : $inverterData_DCV"
  echo " DCW        : $inverterData_DCW"
  echo "Measurements Meter:"
  echo " A          : $meterData_A"
  echo " AphA       : $meterData_AphA"
  echo " AphB       : $meterData_AphB"
  echo " AphC       : $meterData_AphC"
  echo " PhV        : $meterData_PhV"
  echo " PhVphA     : $meterData_PhVphA"
  echo " PhVphB     : $meterData_PhVphB"
  echo " PVphC      : $meterData_PVphC"
  echo " PPV        : $meterData_PPV"
  echo " PhVphAB    : $meterData_PhVphAB"
  echo " PhVphBC    : $meterData_PhVphBC"
  echo " PhVphCA    : $meterData_PhVphCA"
  echo " Hz         : $meterData_Hz"
  echo " W          : $meterData_W"
  echo " WphA       : $meterData_WphA"
  echo " WphB       : $meterData_WphB"
  echo " WphC       : $meterData_WphC"
  echo " VA         : $meterData_VA"
  echo " VAphA      : $meterData_VAphA"
  echo " VAphB      : $meterData_VAphB"
  echo " VAphC      : $meterData_VAphC"
  echo " VAR        : $meterData_VAR"
  echo " VARphA     : $meterData_VARphA"
  echo " VARphB     : $meterData_VARphB"
  echo " VARphC     : $meterData_VARphC"
  echo " PF         : $meterData_PF"
  echo " PFphA      : $meterData_PFphA"
  echo " PFphB      : $meterData_PFphB"
  echo " PFphC      : $meterData_PFphC"
  echo " TotWhExp   : $meterData_TotWhExp"
  echo " TotWhExpPhA: $meterData_TotWhExpPhA"
  echo " TotWhExpPhB: $meterData_TotWhExpPhB"
  echo " TotWhExpPnC: $meterData_TotWhExpPnC"
  echo " TotWhImp   : $meterData_TotWhImp"
  echo " TotWhImpPhA: $meterData_TotWhImpPhA"
  echo " TotWhImpPhB: $meterData_TotWhImpPhB"
  echo " TotWhImpPnC: $meterData_TotWhImpPnC" 
}

# runs initial action only once at startup
function initial_action() {
  local res

  # output time/date of execution
  echo "== $(date) ==================================="

  # lets retrieve all mac<>ip addresses of currently
  # active devices in our network
  echo -n "Querying SolarEdge device:"
  echo -n " ${SE_INVERTER_IP}:${SE_INVERTER_MODBUS_PORT}"
  echo

  # Initial read of common data
  ReadInverterCommonData
  if [[ ${res} -ne $RETURN_SUCCESS ]]; then
    echo "ERROR: couldn't connect to the specified inverter!"
    return ${RETURN_FAILURE}
  fi 
  ReadMeterCommonData
  ProcessCommonData
  echo
}

function run_semon()
{
  local res

  # output time/date of execution
  echo "== $(date) ==================================="

  # Collecting data
  ReadBulkDataInverter
  if [ "$SM_READ_STATUS" == "true" ]; then
    ReadInverterGeneralStatus
  fi
  if [ "$SM_READ_FULL_DATA" == "true" ]; then
    ReadInverterFullData
  else
    ReadInverterBaseData
  fi
  ClearBulkData

  ReadBulkDataMeter
  if [ "$SM_READ_STATUS" == "true" ]; then
    ReadMeterGeneralStatus
  fi
  if [ "$SM_READ_FULL_DATA" == "true" ]; then
    ReadMeterFullData
  else
    ReadMeterBaseData
  fi
  ClearBulkData

  # Process the data
  if [ "$SM_READ_STATUS" == "true" ]; then
    ProcessGeneralStatus
  fi
  if [ "$SM_READ_FULL_DATA" == "true" ]; then
    ProcessFullData
  else
    ProcessBaseData
  fi

  # output some statistics
  echo
  
  echo "== $(date) ==================================="
  echo
  
  return ${RETURN_SUCCESS}
}

################################################
# main processing starts here
#
echo "semon_ccu ${VERSION} - a CCU-based SolarEdge PV-Datalogger"
echo "(${VERSION_DATE}) (c) jensDev <jensDev@t-online.de> - based on hm_pdetect https://github.com/jens-maus/hm_pdetect"
echo

initial_action

# lets enter an endless loop to implement a
# daemon-like behaviour
result=-1
iteration=0
while true; do

  # lets source the config file again
  if [[ -n ${CONFIG_FILE} ]]; then
    source "${CONFIG_FILE}"
    if [[ $? -ne 0 ]]; then
      echo "ERROR: couldn't source config file '${CONFIG_FILE}'. Please check config file syntax."
      result=${RETURN_FAILURE}
    fi

    # lets eval the user overridden variables
    # so that they take priority
    eval ${USERVARS}
  fi

  # lets wait until the next execution round in case
  # the user wants to run it as a daemon
  if [[ ${result} -ge 0 ]]; then
    ((iteration = iteration + 1))
    if [[ -n ${SE_INTERVAL_TIME}    && \
          ${SE_INTERVAL_TIME} -gt 0 && \
          ( -z ${SE_INTERVAL_MAX} || ${SE_INTERVAL_MAX} -eq 0 || ${iteration} -lt ${SE_INTERVAL_MAX} ) ]]; then
      sleep $((${SE_INTERVAL_TIME} * 60))
      if [[ $? -eq 1 ]]; then
        result=${RETURN_FAILURE}
        break
      fi
    else 
      break
    fi
  fi

  # perform one pdetect run and in case we are running in daemon
  # mode and having the processlogfile enabled output to the logfile instead.
  if [[ -n ${SE_PROCESSLOG_FILE} ]]; then
    output=$(run_semon)
    result=$?
    echo "${output}" | cat - ${SE_PROCESSLOG_FILE} | head -n ${SE_PROCESSLOG_MAXLINES} >/tmp/semon_ccu-$$.tmp && mv /tmp/semon_ccu-$$.tmp ${SE_PROCESSLOG_FILE}
  else
    # run pdetect with normal stdout processing
    run_semon
    result=$?
  fi

done

exit ${result}
