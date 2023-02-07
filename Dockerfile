FROM cytopia/bandit

RUN apk add --no-cache --upgrade bash
RUN apk add jq
COPY build.sh .
COPY BP-BASE-SHELL-STEPS .
RUN chmod +x build.sh
ENV ACTIVITY_SUB_TASK_CODE BP-BANDIT-TASK
ENV SLEEP_DURATION 5s
ENV VALIDATION_FAILURE_ACTION WARNING
ENV SCAN_SEVERITY "all"
ENV FORMAT_ARG "html"
ENV OUTPUT_ARG "bandit-report.html"
ENTRYPOINT [ "./build.sh" ]

