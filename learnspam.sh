#!/bin/bash

echo "Analyzing ham messages..."
for i in /var/mail/vmail/*/*/mail/{cur,new}/; do
    rspamc learn_ham $i
    chown -R _rspamd:_rspamd /var/lib/rspamd
done

for i in /var/mail/vmail/*/*/mail/Archive/{cur,new}/; do
    rspamc learn_ham $i
    chown -R _rspamd:_rspamd /var/lib/rspamd
done


echo "Analyzing spam messages..."
for i in /var/mail/vmail/*/*/mail/Junk/{cur,new}/; do
    rspamc learn_spam $i
    chown -R _rspamd:_rspamd /var/lib/rspamd
done
