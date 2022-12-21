#!/bin/bash

echo > /var/log/rspamc_ham.log
echo > /var/log/rspamc_spam.log

echo "Analyzing ham messages..."
for i in /var/mail/vmail/*/*/mail/{cur,new}/; do
    rspamc learn_ham $i >> /var/log/rspamc_ham.log 2>&1
    chown -R _rspamd:_rspamd /var/lib/rspamd
done

for i in /var/mail/vmail/*/*/mail/Archive/{cur,new}/; do
    rspamc learn_ham $i >> /var/log/rspamc_ham.log 2>&1
    chown -R _rspamd:_rspamd /var/lib/rspamd
done


echo "Analyzing spam messages..."
for i in /var/mail/vmail/*/*/mail/Junk/{cur,new}/; do
    rspamc learn_spam $i >> /var/log/rspamc_spam.log 2>&1
    chown -R _rspamd:_rspamd /var/lib/rspamd
done
