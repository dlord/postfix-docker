#!/bin/bash

unwanted_ciphers='CBC'
default_cipherlist=`openssl ciphers 'HIGH:MEDIUM:!LOW:!ADH:!SSLv2:!EXP:!aNULL:!NULL:!CAMELLIA:!RC4:!MD5:!SEED:!3DES' \
    | sed -e 's/:/\n/g' \
    | grep -Ev "$unwanted_ciphers" \
    | sed -e ':a;N;$!ba;s/\n/:/g'`

# Set Postfix configuration from environment.
myhostname=${myhostname:-docker.example.com}
smtpd_helo_restrictions=${smtpd_helo_restrictions:-permit_sasl_authenticated, permit_mynetworks}
smtpd_recipient_restrictions=${smtpd_recipient_restrictions:-reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_invalid_hostname, reject_non_fqdn_sender}
smtpd_tls_security_level=${smtpd_tls_security_level:-may}
smtp_tls_security_level=${smtp_tls_security_level:-may}
smtpd_tls_ciphers=${smtpd_tls_ciphers:-high}
smtp_tls_ciphers=${smtp_tls_ciphers:-high}
tls_high_cipherlist=${tls_high_cipherlist:-$default_cipherlist}
tls_preempt_cipherlist=${tls_preempt_cipherlist:-yes}
smtpd_tls_mandatory_protocols=${smtpd_tls_mandatory_protocols:-'!SSLv2,!SSLv3'}
smtpd_tls_protocols=${smtpd_tls_protocols:-'!SSLv2,!SSLv3'}
smtpd_tls_eecdh_grade=${smtpd_tls_eecdh_grade:-ultra}
smtp_tls_mandatory_protocols=${smtp_tls_mandatory_protocols:-'!SSLv2,!SSLv3'}
smtp_tls_protocols=${smtp_tls_protocols:-'!SSLv2,!SSLv3'}

# Set Dovecot configuration from environment
dovecot_ssl_protocols=${dovecot_ssl_protocols:-'!SSLv2 !SSLv3'}
dovecot_ssl_cipher_list=${dovecot_ssl_cipher_list:-$default_cipherlist}
dovecot_verbose_ssl=${dovecot_verbose_ssl:-no}
dovecot_mail_plugins=${dovecot_mail_plugins:-'$mail_plugins quota'}
dovecot_mail_debug=${dovecot_mail_debug:-no}
dovecot_auth_debug=${dovecot_auth_debug:-no}

if [ -z ${tls_cert_file+x} ]; then
    tls_cert_file="/etc/ssl/private/$myhostname.pem"
fi

if [ -z ${tls_key_file+x} ]; then
    tls_key_file="/etc/ssl/private/$myhostname.key"
fi

if [ -z ${dhparam_file+x} ]; then
    dhparam_file="/etc/ssl/private/dhparam.pem"
fi

postconf -e "myhostname = $myhostname"
postconf -e "smtpd_helo_restrictions = $smtpd_helo_restrictions"
postconf -e "smtpd_recipient_restrictions = $smtpd_recipient_restrictions"
postconf -e "smtpd_tls_cert_file = $tls_cert_file"
postconf -e "smtpd_tls_key_file = $tls_key_file"
postconf -e "smtpd_tls_security_level = $smtpd_tls_security_level"
postconf -e "smtp_tls_security_level = $smtp_tls_security_level"
postconf -e "smtpd_tls_ciphers = $smtpd_tls_ciphers"
postconf -e "smtp_tls_ciphers = $smtp_tls_ciphers"
postconf -e "tls_high_cipherlist = $tls_high_cipherlist"
postconf -e "tls_preempt_cipherlist = $tls_preempt_cipherlist"
postconf -e "smtpd_tls_mandatory_protocols = $smtpd_tls_mandatory_protocols"
postconf -e "smtpd_tls_protocols = $smtpd_tls_protocols"
postconf -e "smtpd_tls_dh1024_param_file = $dhparam_file"
postconf -e "smtpd_tls_eecdh_grade = $smtpd_tls_eecdh_grade"
postconf -e "smtp_tls_mandatory_protocols = $smtp_tls_mandatory_protocols"
postconf -e "smtp_tls_protocols = $smtp_tls_protocols"

# setup self-signed SSL certificate if no certificate exists
if [ ! -f "$tls_key_file" ]; then
    echo "No SSL certificate found for $myhostname. Creating a self-signed one."
    openssl req \
        -nodes \
        -x509 \
        -newkey rsa:4096 \
        -keyout "$tls_key_file" \
        -out "$tls_cert_file" \
        -subj "/C=PH/ST=NCR/L=NCR/O=$myhostname/OU=$myhostname/CN=$myhostname" && \
    chown root:root $tls_cert_file $tls_key_file && \
    chmod 400 $tls_cert_file $tls_key_file
fi

# create DH Param file if none is available
if [ ! -f "$dhparam_file" ]; then
    echo "No DH param file found. Creating a new one: $dhparam_file"
    openssl dhparam -out "$dhparam_file" 2048
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
verbose_ssl = $dovecot_verbose_ssl
ssl_cert = <$tls_cert_file
ssl_key = <$tls_key_file
ssl_client_ca_dir = /etc/ssl/certs
ssl_prefer_server_ciphers = yes
ssl_dh_parameters_length = 2048
ssl_protocols = $dovecot_ssl_protocols
ssl_cipher_list = $dovecot_ssl_cipher_list
mail_home = /var/mail/vmail/%d/%n
mail_uid = 5000
mail_gid = 5000
mail_location = maildir:/var/mail/vmail/%d/%n/mail:LAYOUT=fs
mail_plugins = $dovecot_mail_plugins
mail_debug = $dovecot_mail_debug
auth_debug = $dovecot_auth_debug
auth_username_chars = abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890.-_@

# IMAP configuration
protocol imap {
    mail_plugins = \$mail_plugins imap_quota
    mail_max_userip_connections = 10
    imap_client_workarounds = delay-newmail tb-extra-mailbox-sep
}

# LDA configuration
protocol lda {
    mail_plugins = \$mail_plugins sieve
    postmaster_address = postmaster@$myhostname
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
    quota_grace = 0%%
    quota_rule = *:storage=2GB
    quota_rule2 = Trash:storage=+10%%
    quota_rule3 = Junk:ignore
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
    driver = prefetch
}

userdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf
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
password_query = \
    SELECT \
        eu.username as user, \
        d.name as domain, \
        eu.password, \
        '/var/mail/vmail/%d/%n' as userdb_home, \
        '5000' as userdb_uid, \
        '5000' as userdb_gid, \
        concat('*:storage=', d.user_quota_limit) as userdb_quota_rule \
    FROM \
        postfix_emailuser eu, \
        postfix_domain d \
    WHERE \
        d.id=eu.domain_id \
        AND eu.active=true \
        AND d.active=true \
        AND eu.username='%n' \
        and d.name='%d'
user_query = \
    SELECT \
        '/var/mail/vmail/%d/%n' as home, \
        '5000' as uid, \
        '5000' as gid, \
        concat('*:storage=', d.user_quota_limit) as quota_rule \
    FROM \
        postfix_emailuser eu, \
        postfix_domain d \
    WHERE \
        d.id=eu.domain_id \
        AND eu.active=true \
        AND d.active=true \
        AND eu.username='%n' \
        and d.name='%d'
iterate_query = \
    SELECT \
        eu.username as username, \
        d.name as domain \
    FROM \
        postfix_emailuser eu, \
        postfix_domain d \
    WHERE \
        d.id=eu.domain_id \
        AND eu.active=true \
        AND d.active=true
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
chown -R opendkim:opendkim /etc/opendkim
chown -R opendkim:root /var/spool/postfix/opendkim
chown -R debian-spamd:debian-spamd /var/lib/spamassassin
chown -R debian-spamd:root /var/spool/postfix/spamassassin/
chown -R vmail:vmail /var/mail/vmail
chown -R clamav:adm /var/log/clamav/*
chown clamav:clamav /var/log/clamav
chmod 400 $tls_cert_file $tls_key_file

if [ "$(ls -A /var/lib/clamav)" ]; then
    echo "Clamav signatures found."
else
    echo "Clamav signatures not found. running freshclam for the first time."
    freshclam
fi

# start Postfix and its related services.
function start_all() {
    # ensure that postfix and crond pid file has been removed.
    rm -f \
        /var/spool/postfix/pid/master.pid \
        /var/run/spamass/spamass.pid \
        /var/run/opendkim/opendkim.pid \
        /var/run/crond.pid

    tail -n 0 -f /var/log/syslog &
    TAIL_PID=$!

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

    wait $TAIL_PID
}

function stop_all() {
    echo "Stopping primary services..."
    dovecot stop
    postfix stop
    service clamav-freshclam stop
    service clamav-milter stop
    service clamav-daemon stop

    kill `cat /var/run/spamass/spamass.pid`
    wait `cat /var/run/spamass/spamass.pid` 2>/dev/null

    service spamassassin stop

    kill `cat /var/run/opendkim/opendkim.pid`
    wait `cat /var/run/opendkim/opendkim.pid` 2>/dev/null

    echo "Stopping cron and rsyslog..."
    kill `cat /var/run/crond.pid`
    wait `cat /var/run/crond.pid` 2>/dev/null
    kill `cat /var/run/rsyslogd.pid`
    wait `cat /var/run/rsyslogd.pid` 2>/dev/null

    echo "Stopping remaining processes..."
    kill "$TAIL_PID"
    wait "$TAIL_PID" 2>/dev/null

    echo "Shutdown complete!"
}

trap stop_all EXIT

start_all
