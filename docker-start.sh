#!/bin/bash
ulimit -n 10000

if [ ! -e "/etc/frr/daemons" ]
then
    cp -r /src/etc/frr/. /etc/frr/
fi

source /app/lib/frr/frrcommon.sh
/app/lib/frr/watchfrr $(daemon_list)
