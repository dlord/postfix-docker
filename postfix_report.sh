#!/bin/bash
. /postfix_env

{ echo "Subject: Postfix Summary: $(date -d "-1 day" '+%Y-%m-%d')" && (gunzip -c /var/log/mail.log.0.gz | pflogsumm); } | \
    sendmail -F "Postfix Report" -f "root@$myhostname" "root@$myhostname"
