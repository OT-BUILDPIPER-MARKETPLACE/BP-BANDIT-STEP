#!/bin/bash
source functions.sh
source log-functions.sh
source str-functions.sh
source file-functions.sh
source aws-functions.sh

code="$WORKSPACE/$CODEBASE_DIR" 

logInfoMessage "I'll do the scanning for $WORKSPACE/$CODEBASE_DIR"
logInfoMessage "Executing command"
logInfoMessage "bandit -r $WORKSPACE/$CODEBASE_DIR --severity-level $SCAN_SEVERITY -f $FORMAT_ARG -o $OUTPUT_ARG"
logInfoMessage "I'll scan $WORKSPACE/$CODEBASE_DIR for only [$SCAN_SEVERITY] severities"

sleep $SLEEP_DURATION

if [ -d $code ];then
  bandit -r $WORKSPACE/$CODEBASE_DIR --severity-level $SCAN_SEVERITY -f json
  logInfoMessage "I'll generate report at [$WORKSPACE/$CODEBASE_DIR]"
  bandit -r $WORKSPACE/$CODEBASE_DIR --severity-level $SCAN_SEVERITY -f $FORMAT_ARG -o $OUTPUT_ARG
  logInfoMessage "Congratulations bandit scan succeeded!!!"
  generateOutput $ACTIVITY_SUB_TASK_CODE true "Congratulations bandit scan succeeded!!!"
else
  if [ "$VALIDATION_FAILURE_ACTION" == "FAILURE" ]
  then
    logErrorMessage "$WORKSPACE/$CODEBASE_DIR: No such directory exist"
    logErrorMessage "Please check bandit scan failed!!!"
    generateOutput $ACTIVITY_SUB_TASK_CODE false "Please check bandit scan failed!!!"
    exit 1
  else
    logErrorMessage "$WORKSPACE/$CODEBASE_DIR: No such directory exist"
    logWarningMessage "Please check bandit scan failed!!!"
    generateOutput $ACTIVITY_SUB_TASK_CODE true "Please check bandit scan failed!!!"
  fi
fi
