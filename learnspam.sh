#!/bin/bash

echo "Analyzing ham messages..."
for i in /var/mail/vmail/*/*/mail/{cur,new}/; do
    sa-learn --ham $i
    chown -R debian-spamd:debian-spamd /var/lib/spamassassin
done

echo "Analyzing spam messages..."
for i in /var/mail/vmail/*/*/mail/Junk/; do
    sa-learn --spam $i
    chown -R debian-spamd:debian-spamd /var/lib/spamassassin
done
