#!/bin/bash

# Set Postfix configuration from environment.
myhostname=${myhostname:-docker.example.com}
smtpd_helo_restrictions=${smtpd_helo_restrictions:-permit_sasl_authenticated, permit_mynetworks}
smtpd_recipient_restrictions=${smtpd_recipient_restrictions:-reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_invalid_hostname, reject_non_fqdn_sender}

if [ -z ${tls_cert_file+x} ]; then
    tls_cert_file="/etc/ssl/private/$myhostname.pem"
fi

if [ -z ${tls_key_file+x} ]; then
    tls_key_file="/etc/ssl/private/$myhostname.key"
fi

postconf -e "myhostname = $myhostname"
postconf -e "smtpd_helo_restrictions = $smtpd_helo_restrictions"
postconf -e "smtpd_recipient_restrictions = $smtpd_recipient_restrictions"
postconf -e "smtpd_tls_cert_file = $tls_cert_file" && \
postconf -e "smtpd_tls_key_file = $tls_key_file" && \

# setup self-signed SSL certificate if no certificate exists
if [ ! -f "$tls_key_file" ]; then
    echo "No SSL certificate found for $myhostname. Creating a self-signed one."
    openssl req \
        -nodes \
        -x509 \
        -newkey rsa:4096 \
        -keyout "$tls_key_file" \
        -out "$tls_cert_file" \
        -subj "/C=PH/ST=NCR/L=NCR/O=example.com/OU=example.com/CN=example.com" && \
    chown root:root $tls_cert_file $tls_key_file && \
    chmod 400 $tls_cert_file $tls_key_file
fi

# alias map config
db_host=${db_host:-postfix-db}
db_user=${db_user:-root}
db_password=${db_password:-password}
db_name=${db_name:-postfix}

cat > /etc/postfix/mysql-virtual-mailbox-domains.cf << EOF
user = $db_user
password = $db_password
dbname = $db_name
hosts = $db_host
query = SELECT name FROM postfix_domain WHERE name='%s' AND active=true
EOF

cat > /etc/postfix/mysql-virtual-mailbox-maps.cf << EOF
user = $db_user
password = $db_password
dbname = $db_name
hosts = $db_host
query = SELECT e.email FROM (SELECT concat(eu.username, '@', d.name) as email FROM postfix_emailuser eu, postfix_domain d WHERE d.id=eu.domain_id AND eu.active=true AND d.active=true) e WHERE e.email='%s'
EOF

cat > /etc/postfix/mysql-virtual-alias-maps.cf << EOF
user = $db_user
password = $db_password
dbname = $db_name
hosts = $db_host
query = SELECT destination FROM postfix_alias WHERE source='%s' AND active=true
EOF


# dovecot config
cat > /etc/dovecot/conf.d/99-mail-stack-delivery.conf << EOF
# Some general options
protocols = imap sieve
ssl = yes
ssl_cert = <$tls_cert_file
ssl_key = <$tls_key_file
ssl_client_ca_dir = /etc/ssl/certs
ssl_cipher_list = ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AES:RSA+3DES:!ADH:!AECDH:!MD5:!DSS
mail_home = /var/mail/vmail/%d/%n
mail_location = maildir:/var/mail/vmail/%d/%n/mail:LAYOUT=fs
auth_username_chars = abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890.-_@

# IMAP configuration
protocol imap {
    mail_max_userip_connections = 10
    imap_client_workarounds = delay-newmail tb-extra-mailbox-sep
}

# LDA configuration
protocol lda {
    postmaster_address = postmaster@$myhostname
    mail_plugins = sieve
    quota_full_tempfail = yes
    deliver_log_format = msgid=%m: %$
    rejection_reason = Your message to <%t> was automatically rejected:%n%r
}

# Plugins configuration
plugin {
    sieve=~/.dovecot.sieve
    sieve_dir=~/sieve
    sieve_before = /var/mail/vmail/sieve-before
    sieve_after = /var/mail/vmail/sieve-after

    quota = maildir:User quota
    quota_rule = *:storage=2GB
    quota_rule2 = Trash:storage=+10%%
    quota_rule3 = Junk:storage=+10%%
}

# Authentication configuration
auth_mechanisms = plain login

passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf
    deny = no
    master = no
    pass = no
    skip = never
    result_failure = continue
    result_internalfail = continue
    result_success = return-ok
}

userdb {
    driver = static
    args = uid=5000 gid=5000 home=/var/mail/vmail/%d/%n
}

# Log all failed authentication attempts
auth_verbose=yes

service auth {
    # Postfix smtp-auth
    unix_listener /var/spool/postfix/private/dovecot-auth {
        mode = 0660
        user = postfix
        group = postfix
    }
}
EOF

cat > /etc/dovecot/dovecot-sql.conf << EOF
driver = mysql
connect = host=$db_host dbname=$db_name user=$db_user password=$db_password
default_pass_scheme = SHA512-CRYPT
password_query = SELECT eu.username as user, d.name as domain, eu.password FROM postfix_emailuser eu, postfix_domain d WHERE d.id=eu.domain_id AND eu.active=true AND d.active=true AND eu.username='%n' and d.name='%d'
EOF

# OpenDKIM configuration
if [ ! -f /etc/opendkim/mail ]; then
    echo "No OpenDKIM key found. Generating a new one."
    pushd /etc/opendkim > /dev/null
    opendkim-genkey -r -h sha256 -d $myhostname -s mail && \
        mv mail.private mail

    echo "mail.$myhostname $myhostname:mail:/etc/opendkim/mail" > /etc/opendkim/KeyTable
    echo "*@$myhostname mail.$myhostname" > /etc/opendkim/SigningTable
    echo "127.0.0.1" > /etc/opendkim/TrustedHosts

    chown -R opendkim:opendkim /etc/opendkim
    popd > /dev/null
fi

# ensure spamassasin config is correct
spamassassin --lint

# Update sieve
mkdir -p /var/mail/vmail/sieve-before /var/mail/vmail/sieve-after

if find /var/mail/vmail/sieve-before -mindepth 1 -name "*.sieve" -print -quit | grep -q .; then
    echo "Compiling sieve-before."
    sievec /var/mail/vmail/sieve-before/*.sieve
fi

if find /var/mail/vmail/sieve-after -mindepth 1 -name "*.sieve" -print -quit | grep -q .; then
    echo "Compiling sieve-after."
    sievec /var/mail/vmail/sieve-after/*.sieve
fi

# Ensure folders have the proper permissions.
chown -R opendkim:root /var/spool/postfix/opendkim
chown -R debian-spamd:debian-spamd /var/lib/spamassassin
chown -R debian-spamd:root /var/spool/postfix/spamassassin/
chown -R vmail:vmail /var/mail/vmail

if [ "$(ls -A /var/lib/clamav)" ]; then
    echo "Clamav signatures found."
else
    echo "Clamav signatures not found. running freshclam for the first time."
    freshclam
fi

# start Postfix and its related services.
function start_all() {
    # ensure that postfix and crond pid file has been removed.
    rm -f /var/spool/postfix/pid/master.pid
    cat /dev/null > /var/run/crond.pid

    # reset syslog
    cat /dev/null > /var/log/syslog
    cat /dev/null > /var/log/cron.log
    chown syslog:adm /var/log/syslog

    service rsyslog start
    cron

    service opendkim start
    service spamassassin start
    service spamass-milter start
    service clamav-daemon start
    service clamav-milter start
    service clamav-freshclam start
    service postfix start
    dovecot

    tail -n 1000 -f /var/log/syslog &
    TAIL_PID=$!
    wait $TAIL_PID
}

function stop_all() {
    echo "Shutting down..."
    dovecot stop
    service postfix stop
    service clamav-freshclam stop
    service clamav-milter stop
    service clamav-daemon stop
    service spamass-milter stop
    service spamassassin stop
    service opendkim stop

    kill `cat /var/run/crond.pid`
    kill "$TAIL_PID"
    service rsyslog stop
}

trap stop_all EXIT

start_all
