#!/bin/bash
## EMQ docker image start script
# Huang Rui <vowstar@gmail.com>
# EMQ X Team <support@emqx.io>

## Shell setting
if [[ -n "$DEBUG" ]]; then
    set -ex
else
    set -e
fi

shopt -s nullglob

## Local IP address setting

LOCAL_IP=$(hostname -i | grep -oE '((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])' | head -n 1)

## EMQ Base settings and plugins setting
# Base settings in /opt/emqx/etc/emqx.conf
# Plugin settings in /opt/emqx/etc/plugins

_EMQX_HOME='/opt/emqx'

if [[ -z "$EMQX_NAME" ]]; then
    EMQX_NAME="$(hostname)"
    export EMQX_NAME
fi

if [[ -z "$EMQX_HOST" ]]; then
    if [[ "$EMQX_CLUSTER__K8S__ADDRESS_TYPE" == "dns" ]] && [[ -n "$EMQX_CLUSTER__K8S__NAMESPACE" ]]; then
        EMQX_CLUSTER__K8S__SUFFIX=${EMQX_CLUSTER__K8S__SUFFIX:-"pod.cluster.local"}
        EMQX_HOST="${LOCAL_IP//./-}.$EMQX_CLUSTER__K8S__NAMESPACE.$EMQX_CLUSTER__K8S__SUFFIX"
    elif [[ "$EMQX_CLUSTER__K8S__ADDRESS_TYPE" == 'hostname' ]] && [[ -n "$EMQX_CLUSTER__K8S__NAMESPACE" ]]; then
        EMQX_CLUSTER__K8S__SUFFIX=${EMQX_CLUSTER__K8S__SUFFIX:-'svc.cluster.local'}
        EMQX_HOST=$(grep -h "^$LOCAL_IP" /etc/hosts | grep -o "$(hostname).*.$EMQX_CLUSTER__K8S__NAMESPACE.$EMQX_CLUSTER__K8S__SUFFIX")
    else
        EMQX_HOST="$LOCAL_IP"
    fi
    export EMQX_HOST
fi

if [[ -z "$EMQX_WAIT_TIME" ]]; then
    export EMQX_WAIT_TIME=5
fi

if [[ -z "$EMQX_NODE_NAME" ]]; then
    export EMQX_NODE_NAME="$EMQX_NAME@$EMQX_HOST"
fi

# Set hosts to prevent cluster mode failed

if [[ -z "$EMQX_NODE__PROCESS_LIMIT" ]]; then
    export EMQX_NODE__PROCESS_LIMIT=2097152
fi

if [[ -z "$EMQX_NODE__MAX_PORTS" ]]; then
    export EMQX_NODE__MAX_PORTS=1048576
fi

if [[ -z "$EMQX_NODE__MAX_ETS_TABLES" ]]; then
    export EMQX_NODE__MAX_ETS_TABLES=2097152
fi

if [[ -z "$EMQX__LOG_CONSOLE" ]]; then
    export EMQX__LOG_CONSOLE='console'
fi

if [[ -z "$EMQX_LISTENER__TCP__EXTERNAL__ACCEPTORS" ]]; then
    export EMQX_LISTENER__TCP__EXTERNAL__ACCEPTORS=64
fi

if [[ -z "$EMQX_LISTENER__TCP__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQX_LISTENER__TCP__EXTERNAL__MAX_CLIENTS=1000000
fi

if [[ -z "$EMQX_LISTENER__SSL__EXTERNAL__ACCEPTORS" ]]; then
    export EMQX_LISTENER__SSL__EXTERNAL__ACCEPTORS=32
fi

if [[ -z "$EMQX_LISTENER__SSL__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQX_LISTENER__SSL__EXTERNAL__MAX_CLIENTS=500000
fi

if [[ -z "$EMQX_LISTENER__WS__EXTERNAL__ACCEPTORS" ]]; then
    export EMQX_LISTENER__WS__EXTERNAL__ACCEPTORS=16
fi

if [[ -z "$EMQX_LISTENER__WS__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQX_LISTENER__WS__EXTERNAL__MAX_CLIENTS=250000
fi

# Fix issue #42 - export env EMQX_DASHBOARD__DEFAULT_USER__PASSWORD to configure
# 'dashboard.default_user.password' in etc/plugins/emqx_dashboard.conf
if [[ -n "$EMQX_ADMIN_PASSWORD" ]]; then
    export EMQX_DASHBOARD__DEFAULT_USER__PASSWORD=$EMQX_ADMIN_PASSWORD
fi

# fill tuples on specific file
# SYNOPSIS
#     fill_tuples FILE [ELEMENTS ...]
fill_tuples() {
    local file=$1
    local elements=${*:2}
    for var in $elements; do
        if grep -qE "\{\s*$var\s*,\s*(true|false)\s*\}\s*\." "$file"; then
            sed -i -r "s/\{\s*($var)\s*,\s*(true|false)\s*\}\s*\./{\1, true}./1" "$file"
        elif grep -q "$var\s*\." "$file"; then
            # backward compatible.
            sed -i -r "s/($var)\s*\./{\1, true}./1" "$file"
        else
            sed -i '$a'\\ "$file"
            echo "{$var, true}." >>"$file"
        fi
    done
}

## EMQX Plugin load settings
# Plugins loaded by default
LOADED_PLUGINS="$_EMQX_HOME/data/loaded_plugins"
if [[ -n "$EMQX_LOADED_PLUGINS" ]]; then
    EMQX_LOADED_PLUGINS=$(echo "$EMQX_LOADED_PLUGINS" | tr -d '[:cntrl:]' | sed -r -e 's/^[^A-Za-z0-9_]+//g' -e 's/[^A-Za-z0-9_]+$//g' -e 's/[^A-Za-z0-9_]+/ /g')
    echo "EMQX_LOADED_PLUGINS=$EMQX_LOADED_PLUGINS"
    # Parse module names and place `{module_name, true}.` tuples in `loaded_plugins`.
    fill_tuples "$LOADED_PLUGINS" "$EMQX_LOADED_PLUGINS"
fi

## EMQX Modules load settings
# Modules loaded by default
LOADED_MODULES="$_EMQX_HOME/data/loaded_modules"
if [[ -n "$EMQX_LOADED_MODULES" ]]; then
    EMQX_LOADED_MODULES=$(echo "$EMQX_LOADED_MODULES" | tr -d '[:cntrl:]' | sed -r -e 's/^[^A-Za-z0-9_]+//g' -e 's/[^A-Za-z0-9_]+$//g' -e 's/[^A-Za-z0-9_]+/ /g')
    echo "EMQX_LOADED_MODULES=$EMQX_LOADED_MODULES"
    # Parse module names and place `{module_name, true}.` tuples in `loaded_modules`.
    fill_tuples "$LOADED_MODULES" "$EMQX_LOADED_MODULES"
fi

exec "$@"
