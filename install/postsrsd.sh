#!/usr/bin/with-contenv sh
# used to read environment variables

set -e

PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export PATH

# run postsrsd
echo SRS_DOMAIN: $SRS_DOMAIN
echo SRS_SECRET: $SRS_SECRET
/usr/sbin/postsrsd -e

ret=$?
sleep 1
exit $ret
