#!/bin/bash

set -e

PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export PATH

# run cron
/usr/sbin/crond -f -l 6

ret=$?
sleep 1
exit $ret
