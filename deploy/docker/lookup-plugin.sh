#!/bin/bash

KEY=$1
HOME_DIR=$2

# shellcheck disable=SC2206
IFS='.' TOKENS=( $KEY )

MAYBE_CONF_0="$HOME_DIR/etc/plugins/emqx_${TOKENS[0]}.conf"
MAYBE_CONF_1="$HOME_DIR/etc/plugins/emqx_${TOKENS[0]}_${TOKENS[1]}.conf"

if [ -f "$MAYBE_CONF_0" ]; then
  echo "$MAYBE_CONF_0"
elif [ -f "$MAYBE_CONF_1" ]; then
  echo "$MAYBE_CONF_1"
elif [ "${TOKENS[0]}" = "auth" ]; then
  if [ "${TOKENS[1]}" = "client" ] || [ "${TOKENS[1]}" = "user" ]; then
    echo "$HOME_DIR/etc/plugins/emqx_auth_mnesia.conf"
  fi
elif [ "${TOKENS[0]}" = "mqtt" ] && [ "${TOKENS[1]}" = "sn" ]; then
  echo "$HOME_DIR/etc/plugins/emqx_sn.conf"
else
  echo "$HOME_DIR/etc/emqx.conf"
fi
