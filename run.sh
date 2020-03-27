#!/bin/sh
#
# wrapper script to execute semon_ccu.sh in non-daemon
# mode with the possibility to run it a certain amount
# of time by specifying the maximum iterations and
# interval time as command-line options
#
# Example:
# -------
#
# Runs semon_ccu only once:
#
# $ /usr/local/addons/semon_ccu/run.sh
#
# Runs semon_ccu 10 times with a waittime of 5
# seconds between each execution:
#
# $ /usr/local/addons/semon_ccu/run.sh 10 5
#
# Based on https://github.com/jens-maus/hm_pdetect/blob/master/addon/common/run.sh
#

# directory path to semon_ccu addon dir.
#ADDON_DIR=/usr/local/addons/semon_ccu
ADDON_DIR=.

# set settings - they override config-setting
export SE_PROCESSLOG_FILE=
export CONFIG_FILE="${ADDON_DIR}/etc/semon_ccu.conf"

# the interval settings can be specified on the command-line
if [ $# -gt 0 ]; then
  export SE_INTERVAL_MAX=${1}
  if [ $# -gt 1 ]; then
    export SE_INTERVAL_TIME=${2}
  else
    export SE_INTERVAL_TIME=15
  fi
else
  # otherwise do one iteration only with no
  # defined interval time
  export SE_INTERVAL_MAX=1
  export SE_INTERVAL_TIME=
fi

# execute semon_ccu in non-daemon mode
export PATH="${ADDON_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${ADDON_DIR}/bin:${LD_LIBRARY_PATH}"
${ADDON_DIR}/bin/semon_ccu.sh #>/dev/null 2>&1
