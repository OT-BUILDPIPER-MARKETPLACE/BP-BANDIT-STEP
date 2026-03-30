#!/bin/bash

###############################################
### EVENTS TRACKING
###############################################
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/mi-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh

EVENTS='{}'

add_event() {
  local key="${1:-}"
  local status="${2:-}"
  local reason="${3:-}"
  local message="${4:-}"

  if [ -z "$key" ] || [ -z "$status" ]; then
    logErrorMessage "add_event requires at least 'key' and 'status' parameters" >&2
    return 1
  fi

  key="$(echo "$key" | tr '_' ' ' | tr '-' ' ' | tr '[:upper:]' '[:lower:]')"

  EVENTS=$(jq \
    --arg k "$key" \
    --arg status "$status" \
    --arg reason "$reason" \
    --arg message "$message" \
    '. + {
      ($k): {
        status: $status,
        reason: $reason,
        message: $message
      }
    }' <<< "$EVENTS") || {
    logErrorMessage "Failed to add event to EVENTS JSON" >&2
    return 1
  }

  return 0
}

###############################################
### OUTPUT FILE
###############################################
BANDIT_OUTPUT_FILE="${BANDIT_OUTPUT_FILE:-${ACTIVITY_SUB_TASK_CODE}_output.json}"

###############################################
### CHECK BANDIT IS INSTALLED
###############################################
if ! command -v bandit &> /dev/null; then
  logErrorMessage "Bandit could not be found. Please install Bandit first."
  add_event "bandit installation check" "Failed" "Bandit not found" "bandit binary is not available in PATH"
  exit 1
fi
add_event "bandit installation check" "Successful" "Bandit is available" "bandit binary found in PATH"

logInfoMessage "The Bandit Script execution has started"
logInfoMessage "Python version: $(python --version 2>&1)"

###############################################
### INPUT VALIDATION
###############################################
if [[ -z "$CODEBASE_DIR" ]]; then
  logErrorMessage "CODEBASE_DIR is not set"
  add_event "input validation" "Failed" "Missing CODEBASE_DIR" "CODEBASE_DIR environment variable is not set"
  exit 1
fi
add_event "input validation" "Successful" "Required variables present" "CODEBASE_DIR is set to '$CODEBASE_DIR'"

TARGET_DIR="/bp/workspace/${CODEBASE_DIR}"

if [[ ! -d "$TARGET_DIR" ]]; then
  logErrorMessage "Target directory does not exist: $TARGET_DIR"
  add_event "target directory check" "Failed" "Directory not found" "Target path $TARGET_DIR does not exist"
  exit 1
fi
add_event "target directory check" "Successful" "Directory exists" "Target path $TARGET_DIR is valid"

###############################################
### THRESHOLD CONFIGURATION
### Severity-based thresholds — max issues allowed per level
###   BANDIT_THRESHOLD_HIGH   : default -1 (disabled)
###   BANDIT_THRESHOLD_MEDIUM : default -1 (disabled)
###   BANDIT_THRESHOLD_LOW    : default -1 (disabled)
###   BANDIT_THRESHOLD_TOTAL  : default -1 (disabled)
### Set any value to -1 to disable that specific threshold
###############################################
BANDIT_THRESHOLD_HIGH="${BANDIT_THRESHOLD_HIGH:--1}"
BANDIT_THRESHOLD_MEDIUM="${BANDIT_THRESHOLD_MEDIUM:--1}"
BANDIT_THRESHOLD_LOW="${BANDIT_THRESHOLD_LOW:--1}"
BANDIT_THRESHOLD_TOTAL="${BANDIT_THRESHOLD_TOTAL:--1}"

###############################################
### THRESHOLD CHECK FUNCTION
###############################################
function checkThreshold() {
  local high=$1
  local medium=$2
  local low=$3
  local total=$4
  local breached=0

  logInfoMessage "-------------------------------------------"
  logInfoMessage "THRESHOLD CHECK"
  logInfoMessage "  Severity  | Detected | Allowed"
  logInfoMessage "  ----------|----------|--------"
  logInfoMessage "$(printf "  %-9s | %-8s | %s" "HIGH"   "$high"   "$([ "$BANDIT_THRESHOLD_HIGH"   == "-1" ] && echo "disabled" || echo "$BANDIT_THRESHOLD_HIGH")")"
  logInfoMessage "$(printf "  %-9s | %-8s | %s" "MEDIUM" "$medium" "$([ "$BANDIT_THRESHOLD_MEDIUM" == "-1" ] && echo "disabled" || echo "$BANDIT_THRESHOLD_MEDIUM")")"
  logInfoMessage "$(printf "  %-9s | %-8s | %s" "LOW"    "$low"    "$([ "$BANDIT_THRESHOLD_LOW"    == "-1" ] && echo "disabled" || echo "$BANDIT_THRESHOLD_LOW")")"
  logInfoMessage "$(printf "  %-9s | %-8s | %s" "TOTAL"  "$total"  "$([ "$BANDIT_THRESHOLD_TOTAL"  == "-1" ] && echo "disabled" || echo "$BANDIT_THRESHOLD_TOTAL")")"
  logInfoMessage "-------------------------------------------"

  # Check HIGH
  if [[ "$BANDIT_THRESHOLD_HIGH" != "-1" ]] && [[ "$high" -gt "$BANDIT_THRESHOLD_HIGH" ]]; then
    logErrorMessage "HIGH threshold breached: found $high, allowed $BANDIT_THRESHOLD_HIGH"
    add_event "threshold check high" "Failed" "HIGH threshold breached" "Found $high HIGH issue(s), allowed limit is $BANDIT_THRESHOLD_HIGH"
    breached=1
  elif [[ "$BANDIT_THRESHOLD_HIGH" != "-1" ]]; then
    add_event "threshold check high" "Successful" "Within HIGH limit" "Found $high HIGH issue(s), allowed limit is $BANDIT_THRESHOLD_HIGH"
  else
    add_event "threshold check high" "Successful" "HIGH threshold disabled" "BANDIT_THRESHOLD_HIGH=-1"
  fi

  # Check MEDIUM
  if [[ "$BANDIT_THRESHOLD_MEDIUM" != "-1" ]] && [[ "$medium" -gt "$BANDIT_THRESHOLD_MEDIUM" ]]; then
    logErrorMessage "MEDIUM threshold breached: found $medium, allowed $BANDIT_THRESHOLD_MEDIUM"
    add_event "threshold check medium" "Failed" "MEDIUM threshold breached" "Found $medium MEDIUM issue(s), allowed limit is $BANDIT_THRESHOLD_MEDIUM"
    breached=1
  elif [[ "$BANDIT_THRESHOLD_MEDIUM" != "-1" ]]; then
    add_event "threshold check medium" "Successful" "Within MEDIUM limit" "Found $medium MEDIUM issue(s), allowed limit is $BANDIT_THRESHOLD_MEDIUM"
  else
    add_event "threshold check medium" "Successful" "MEDIUM threshold disabled" "BANDIT_THRESHOLD_MEDIUM=-1"
  fi

  # Check LOW
  if [[ "$BANDIT_THRESHOLD_LOW" != "-1" ]] && [[ "$low" -gt "$BANDIT_THRESHOLD_LOW" ]]; then
    logErrorMessage "LOW threshold breached: found $low, allowed $BANDIT_THRESHOLD_LOW"
    add_event "threshold check low" "Failed" "LOW threshold breached" "Found $low LOW issue(s), allowed limit is $BANDIT_THRESHOLD_LOW"
    breached=1
  elif [[ "$BANDIT_THRESHOLD_LOW" != "-1" ]]; then
    add_event "threshold check low" "Successful" "Within LOW limit" "Found $low LOW issue(s), allowed limit is $BANDIT_THRESHOLD_LOW"
  else
    add_event "threshold check low" "Successful" "LOW threshold disabled" "BANDIT_THRESHOLD_LOW=-1"
  fi

  # Check TOTAL
  if [[ "$BANDIT_THRESHOLD_TOTAL" != "-1" ]] && [[ "$total" -gt "$BANDIT_THRESHOLD_TOTAL" ]]; then
    logErrorMessage "TOTAL threshold breached: found $total, allowed $BANDIT_THRESHOLD_TOTAL"
    add_event "threshold check total" "Failed" "TOTAL threshold breached" "Found $total total issue(s), allowed limit is $BANDIT_THRESHOLD_TOTAL"
    breached=1
  elif [[ "$BANDIT_THRESHOLD_TOTAL" != "-1" ]]; then
    add_event "threshold check total" "Successful" "Within TOTAL limit" "Found $total total issue(s), allowed limit is $BANDIT_THRESHOLD_TOTAL"
  else
    add_event "threshold check total" "Successful" "TOTAL threshold disabled" "BANDIT_THRESHOLD_TOTAL=-1"
  fi

  return $breached
}

###############################################
### SCAN
###############################################
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="bandit_output_${TIMESTAMP}.csv"
JSON_TEMP="/tmp/bandit_raw_${TIMESTAMP}.json"

logInfoMessage "Running Bandit scan on: $TARGET_DIR"
logInfoMessage "Generating Summary: Bandit"

# Print human-readable summary to stdout
bandit -r "$TARGET_DIR" 2>/dev/null | awk '/Code scanned:/, /Files skipped/'

logInfoMessage "Executing: bandit -r "$TARGET_DIR" -f json -o "$JSON_TEMP""
# Run scan to JSON (for metric extraction)
bandit -r "$TARGET_DIR" -f json -o "$JSON_TEMP" 2>/dev/null
BANDIT_EXIT_CODE=$?

if [[ "$BANDIT_EXIT_CODE" -eq 0 ]]; then
  add_event "bandit scan" "Successful" "No issues detected" "bandit completed — no security issues found in $TARGET_DIR"
elif [[ "$BANDIT_EXIT_CODE" -eq 1 ]]; then
  add_event "bandit scan" "Successful" "Issues detected" "bandit completed — security issues found in $TARGET_DIR"
else
  add_event "bandit scan" "Failed" "Bandit execution error" "bandit exited with unexpected code $BANDIT_EXIT_CODE"
  logErrorMessage "Bandit scan failed with exit code $BANDIT_EXIT_CODE"
  exit $BANDIT_EXIT_CODE
fi

# Also produce the CSV report
bandit -r "$TARGET_DIR" -f csv -o "/bp/execution_dir/$GLOBAL_TASK_ID/$OUTPUT_FILE" 2>/dev/null
add_event "generate csv report" "Successful" "CSV report saved" "Report written to /bp/execution_dir/$GLOBAL_TASK_ID/$OUTPUT_FILE"

logInfoMessage "Bandit scan completed. Report saved to $OUTPUT_FILE"

###############################################
### PARSE METRICS FROM JSON OUTPUT
###############################################
if [[ ! -f "$JSON_TEMP" ]]; then
  logWarningMessage "JSON output not found. Defaulting all counts to 0."
  add_event "parse scan results" "Warning" "JSON output missing" "Could not find $JSON_TEMP, counts defaulted to 0"
  COUNT_HIGH=0
  COUNT_MEDIUM=0
  COUNT_LOW=0
  COUNT_TOTAL=0
else
  COUNT_HIGH=$(jq '[.results[] | select(.issue_severity == "HIGH")] | length' "$JSON_TEMP" 2>/dev/null || echo 0)
  COUNT_MEDIUM=$(jq '[.results[] | select(.issue_severity == "MEDIUM")] | length' "$JSON_TEMP" 2>/dev/null || echo 0)
  COUNT_LOW=$(jq '[.results[] | select(.issue_severity == "LOW")] | length' "$JSON_TEMP" 2>/dev/null || echo 0)
  COUNT_TOTAL=$(jq '.results | length' "$JSON_TEMP" 2>/dev/null || echo 0)

  COUNT_HIGH="${COUNT_HIGH:-0}"
  COUNT_MEDIUM="${COUNT_MEDIUM:-0}"
  COUNT_LOW="${COUNT_LOW:-0}"
  COUNT_TOTAL="${COUNT_TOTAL:-0}"

  add_event "parse scan results" "Successful" "Metrics extracted" "HIGH=$COUNT_HIGH MEDIUM=$COUNT_MEDIUM LOW=$COUNT_LOW TOTAL=$COUNT_TOTAL"
fi

###############################################
### THRESHOLD EVALUATION
###############################################
checkThreshold "$COUNT_HIGH" "$COUNT_MEDIUM" "$COUNT_LOW" "$COUNT_TOTAL"
THRESHOLD_STATUS=$?

###############################################
### DETERMINE FINAL STATUS
###############################################
if [[ "$THRESHOLD_STATUS" -ne 0 ]]; then
  TASK_STATUS=1
  FINAL_STATUS="failed"
  FINAL_REASON="Threshold breached"
  FINAL_MESSAGE="Bandit scan found issues exceeding configured thresholds — HIGH=$COUNT_HIGH MEDIUM=$COUNT_MEDIUM LOW=$COUNT_LOW TOTAL=$COUNT_TOTAL"
else
  TASK_STATUS=0
  FINAL_STATUS="Successful"
  FINAL_REASON="Scan completed"
  FINAL_MESSAGE="Bandit scan passed all thresholds — HIGH=$COUNT_HIGH MEDIUM=$COUNT_MEDIUM LOW=$COUNT_LOW TOTAL=$COUNT_TOTAL"
fi

###############################################
### BUILD ERROR EVENTS LIST
###############################################
ERROR_EVENTS=$(echo "$EVENTS" | jq '[to_entries[] | select(.value.status == "Failed") | .key]')

###############################################
### MAP STATUS TO BOOLEAN
### Matches cloning_repository_output.json format
### where build.status is true/false (not a string)
###############################################
if [[ "$FINAL_STATUS" == "Successful" ]]; then
  STATUS_BOOL="true"
else
  STATUS_BOOL="false"
fi

###############################################
### CREATE STRUCTURED OUTPUT JSON
### build.events  → read by BuildPiper UI "All Events" panel
### output_vars   → available to downstream pipeline steps
###############################################
mkdir -p "/bp/execution_dir/$GLOBAL_TASK_ID"

if ! jq -n \
  --argjson events "$EVENTS" \
  --argjson error_events "$ERROR_EVENTS" \
  --argjson status_bool "$STATUS_BOOL" \
  --arg final_reason "$FINAL_REASON" \
  --arg final_message "$FINAL_MESSAGE" \
  --arg target_dir "$TARGET_DIR" \
  --arg output_file "$OUTPUT_FILE" \
  --argjson count_high "$COUNT_HIGH" \
  --argjson count_medium "$COUNT_MEDIUM" \
  --argjson count_low "$COUNT_LOW" \
  --argjson count_total "$COUNT_TOTAL" \
  --arg threshold_high "$BANDIT_THRESHOLD_HIGH" \
  --arg threshold_medium "$BANDIT_THRESHOLD_MEDIUM" \
  --arg threshold_low "$BANDIT_THRESHOLD_LOW" \
  --arg threshold_total "$BANDIT_THRESHOLD_TOTAL" \
  '{
    build: {
      status: $status_bool,
      reason: $final_reason,
      message: $final_message,
      events: $events,
      current_error: (if $status_bool == "false" then $final_reason else "" end),
      error_events: $error_events
    },
    output_vars: {
      bandit_scan: {
        status: $status_bool,
        reason: $final_reason,
        message: $final_message,
        scan: {
          target_dir: $target_dir,
          report_file: $output_file
        },
        results: {
          issues: {
            high:   $count_high,
            medium: $count_medium,
            low:    $count_low,
            total:  $count_total
          },
          thresholds: {
            high:   $threshold_high,
            medium: $threshold_medium,
            low:    $threshold_low,
            total:  $threshold_total
          }
        },
        current_error: (if $status_bool == "false" then $final_reason else "" end),
        error_events: $error_events
      }
    }
  }' > "/bp/execution_dir/$GLOBAL_TASK_ID/$BANDIT_OUTPUT_FILE"; then
  logInfoMessage "Failed to create bandit output JSON"
  add_event "create output" "Failed" "File creation failed" "Could not write $BANDIT_OUTPUT_FILE"
else
  logInfoMessage "Output JSON written to /bp/execution_dir/$GLOBAL_TASK_ID/$BANDIT_OUTPUT_FILE"
  add_event "create output" "Successful" "Output file created" "Structured output written to $BANDIT_OUTPUT_FILE"
fi

###############################################
### CLEANUP TEMP FILES
###############################################
rm -f "$JSON_TEMP"

###############################################
### SEND MI DATA IF ENABLED
###############################################
if [[ -n "${MI_SERVER_ADDRESS}" ]]; then
  echo -e "total_issues\n$COUNT_TOTAL" > bandit_sum.csv

  export base64EncodedResponse=$(encodeFileContent bandit_sum.csv)
  export application="${APPLICATION_NAME:-}"
  export environment="${PROJECT_ENV_NAME:-$(getProjectEnv)}"
  export service="${COMPONENT_NAME:-$(getServiceName)}"
  export organization="${ORGANIZATION:-}"
  export source_key="${SOURCE_KEY:-bandit}"

  # Must be JSON null (no quotes) or a quoted string - never empty
  if [[ -z "$REPORT_FILE_PATH" || "$REPORT_FILE_PATH" == "null" ]]; then
    export report_file_path="null"
  else
    export report_file_path="\"$REPORT_FILE_PATH\""
  fi

  generateMIDataJson /opt/buildpiper/data/mi.template /tmp/bandit.mi
  logInfoMessage "DEBUG: bandit.mi content: $(cat /tmp/bandit.mi)"
  if sendMIData /tmp/bandit.mi "${MI_SERVER_ADDRESS}"; then
    add_event "send mi data" "Successful" "MI data sent" "Metrics sent to $MI_SERVER_ADDRESS"
  else
    add_event "send mi data" "Failed" "MI send error" "Failed to send metrics to $MI_SERVER_ADDRESS"
  fi
fi

###############################################
### SIGNAL PASS/FAIL TO BUILDPIPER PIPELINE
### CRITICAL: generateOutput is what actually
### stops the pipeline — just exiting is not enough
###############################################
if [[ "$TASK_STATUS" -eq 0 ]]; then
  logInfoMessage "Congratulations! Bandit scan passed."
  generateOutput ${ACTIVITY_SUB_TASK_CODE} true "$FINAL_MESSAGE"
elif [[ "${VALIDATION_FAILURE_ACTION:-FAILURE}" == "FAILURE" ]]; then
  logErrorMessage "Bandit scan FAILED. Stopping pipeline."
  generateOutput ${ACTIVITY_SUB_TASK_CODE} false "$FINAL_MESSAGE"
  exit 1
else
    logWarningMessage "Bandit scan failed, but the step is configured as NON-BLOCKING (warning mode).

  If you want the pipeline to FAIL on leaks:
  - Go to job template settings
  - Set VALIDATION_FAILURE_ACTION = FAILURE

  Current setting allows pipeline to continue."
    add_event "validation mode" "Successful" "Non-blocking validation" "Scan failed but pipeline continued because VALIDATION_FAILURE_ACTION is not FAILURE"
    generateOutput ${ACTIVITY_SUB_TASK_CODE} false "$FINAL_MESSAGE"  
fi

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
