#!/bin/sh
set -e -u

. /opt/emqx/releases/emqx_vars

emqx_exit(){
    # At least erlang.log.1 exists
    if [ -f /opt/emqx/log/erlang.log.1 ]; then
        # tail emqx.log.*
        erlang_log=$(echo $(ls -t /opt/emqx/log/erlang.log.*) | awk '{print $1}')
        num=$(sed -n -e '/LOGGING STARTED/=' ${erlang_log} | tail -1)
        [ ! -z $num ] && [ $num -gt 2 ] && tail -n +$(expr $num - 2) ${erlang_log}
    fi

    echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqx exit abnormally"
    exit 1
}

## EMQ Main script

# When receiving the EXIT signal, execute emqx_exit function
trap "emqx_exit" EXIT

# Start and run emqx, and when emqx crashed, this container will stop
/opt/emqx/bin/emqx start

# Sleep 5 seconds to wait for the loaded plugins catch up.
sleep 5

echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqx start"

## Fork tailing erlang.log, the fork is not killed after this script exits
## The assumption is that this is the docker entrypoint,
## hence docker container is terminated after entrypoint exists
tail -f /opt/emqx/log/erlang.log.1 &

# monitor emqx is running, or the docker must stop to let docker PaaS know
# warning: never use infinite loops such as `` while true; do sleep 1000; done`` here
#          you must let user know emqx crashed and stop this container,
#          and docker dispatching system can known and restart this container.
IDLE_TIME=0
ERTS="/opt/emqx/erts-$ERTS_VSN"
MGMT_CONF='/opt/emqx/etc/plugins/emqx_management.conf'
MGMT_SCHEMA="$(find /opt/emqx/lib -name "emqx_management*" -type d)/priv/emqx_management.schema"

# prevent interpretation by cuttlefish
_EMQX_NODE_NAME="$EMQX_NODE_NAME"
unset EMQX_NODE_NAME

MGMT_CONFIG_ARGS=`$ERTS/bin/escript /opt/emqx/bin/cuttlefish -i $MGMT_SCHEMA -c $MGMT_CONF -d /tmp/configs generate`
MGMT_CONFIG_FILE=`echo "$MGMT_CONFIG_ARGS" | sed -n 's/^.*\(-config[[:space:]]\)//p' | awk '{print $1}'`
MGMT_PORT=$(sed -n s/\{listeners,[\{http,[[:digit:]]//p $MGMT_CONFIG_FILE | sed -e 's/[^0-9]//g')
EMQX_NODE_NAME="$_EMQX_NODE_NAME"

while [ $IDLE_TIME -lt 5 ]; do
    IDLE_TIME=$(expr $IDLE_TIME + 1)
    if curl http://localhost:${MGMT_PORT}/status >/dev/null 2>&1; then
        IDLE_TIME=0
        # Print the latest erlang.log
        now_erlang_log=$(ps -ef |grep "tail -f /opt/emqx/log/erlang.log" |grep -v grep | sed -r "s/.*tail -f (.*)/\1/g")
        new_erlang_log="$(ls -t /opt/emqx/log/erlang.log.* | head -1)"
        if [ $now_erlang_log != $new_erlang_log ];then
            tail -f $new_erlang_log &
            kill $(ps -ef |grep "tail -f $now_erlang_log" | grep -v grep | awk '{print $1}')
        fi
    else
        echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqx not running, waiting for recovery in $((25-IDLE_TIME*5)) seconds"
    fi
    sleep 5
done

# If running to here (the result 5 times not is running, thus in 25s emqx is not running), exit docker image
# Then the high level PaaS, e.g. docker swarm mode, will know and alert, rebanlance this service
