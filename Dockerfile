FROM cytopia/bandit

RUN apk add --no-cache --upgrade bash
RUN apk add --no-cache jq curl gettext

RUN mkdir -p \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /bp/workspace \
    /bp/execution_dir

COPY build.sh .
COPY BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/
COPY BP-BASE-SHELL-STEPS/data /opt/buildpiper/data/

RUN chmod +x build.sh

ENV SLEEP_DURATION="5s" \
    VALIDATION_FAILURE_ACTION="WARNING" \
    SCAN_SEVERITY="all" \
    FORMAT_ARG="csv" \
    OUTPUT_ARG="bandit_report.csv" \
    MI_SERVER_ADDRESS="" \
    REPORT_FILE_PATH="" \
    SOURCE_KEY="bandit" \
    APPLICATION_NAME="" \
    ORGANIZATION=""

ENTRYPOINT [ "./build.sh" ]
