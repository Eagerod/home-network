#!/usr/bin/env bash
#
set -eufo pipefail

DEPLOYMENT="rmq-http-bridge-worker"
MAX_REPLICAS=6
MIN_REPLICAS=2
MAX_MESSAGES=100

last_result=

# Forces the -u failure to not be in a pipeline.
if [ -z "$TASK_SERVER_URL" ]; then
    echo >&2 "Failed to find TASK_SERVER_URL"
    exit 1
fi
if [ -z "$DEPLOYMENT" ]; then
    echo >&2 "Failed to find DEPLOYMENT"
    exit 1
fi

current_replicas=$(kubectl get deployment $DEPLOYMENT -o template='{{.status.replicas}}')

# Update number of replicas once every 3 minutes, just in case anything weird
#   happened.
i=0

# Conditions for an up-scale/down-scale event:
# If sustained flow with the current rates for 1 minute results in >
#   MAX_MESSAGES, and the current number of replicas is < MAX_REPLICAS, add a
#   replica.
# If sustained flow with the current rates for 1 minute results in < 0
#   messages, and the current number of replicas is > MIN_REPLICAS, eliminate
#   a replica.
# Otherwise, do nothing.
# In every case, require 2 readings of the same result to trigger an event.
while true; do
    r=$(curl -fsSL "$TASK_SERVER_URL/stats" | jq '.Messages + (.InRate - .OutRate) * 60' | awk -F. '{print $1}')
    if [ "$r" -ge "$MAX_MESSAGES" ] && [ "$current_replicas" -lt "$MAX_REPLICAS" ]; then
        last_result="${last_result}1"
    elif [ "$r" -le 0 ] && [ "$current_replicas" -gt "$MIN_REPLICAS" ]; then
        last_result="${last_result}0"
    else
        last_result=""
    fi

    # Wait an extra 5 seconds after a scaling event.
    if [ "$last_result" = "11" ]; then
        echo >&2 "Scaling up the current number of replicas ($current_replicas) by 1"
        current_replicas=$((current_replicas + 1))
        kubectl scale deployment $DEPLOYMENT --replicas=$current_replicas
        last_result=""
        sleep 5
    elif [ "$last_result" = "00" ]; then
        echo >&2 "Scaling down the current number of replicas ($current_replicas) by 1"
        current_replicas=$((current_replicas - 1))
        kubectl scale deployment $DEPLOYMENT --replicas=$current_replicas
        last_result=""
        sleep 5
    elif [ ${#last_result} -ge 2 ]; then
        echo >&2 "High volatility recently. Resetting measurements."
        last_result=""
    fi

    sleep 5
    i=$((i + 1))
    if [ "$i" -ge 36 ]; then
        new_replicas=$(kubectl get deployment $DEPLOYMENT -o template='{{.status.replicas}}')
        if [ "$new_replicas" -ne "$current_replicas" ]; then
            current_replicas=$new_replicas
            echo >&2 "Restored number of replicas to $current_replicas"
        fi
        i=0
    fi
done
