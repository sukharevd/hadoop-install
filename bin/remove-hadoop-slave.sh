#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [ -z $1 ]; then
  echo "This script requires a parameter (host)."
  exit 400
fi

HOST=$1
SLAVES_FILE=$HADOOP_CONF_DIR/slaves

grep -Fvx "$HOST" $SLAVES_FILE > /tmp/slaves-file
mv /tmp/slaves-file $SLAVES_FILE

# verify it
[ -z `grep -Fx "$HOST" "$SLAVES_FILE"` ] && exit 0
exit 500
