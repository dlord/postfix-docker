#!/bin/bash

# Set Postfix configuration from environment.

postconf -e "myhostname = $myhostname"
postconf -e "smtpd_helo_restrictions = $smtpd_helo_restrictions"
postconf -e "smtpd_recipient_restrictions = $smtpd_recipient_restrictions"

# alias map config
cat > /etc/postfix/mysql-virtual-mailbox-domains.cf << EOF
user = $db_user
password = $db_password
dbname = $db_name
hosts = $db_host
query = SELECT name FROM domain WHERE name='%s' AND active=true
EOF

cat > /etc/postfix/mysql-virtual-mailbox-maps.cf << EOF
user = $db_user
password = $db_password
dbname = $db_name
hosts = $db_host
query = SELECT email FROM user WHERE email='%s' AND active=true
EOF

cat > /etc/postfix/mysql-virtual-alias-maps.cf << EOF
user = $db_user
password = $db_password
dbname = $db_name
hosts = $db_host
query = SELECT destination FROM alias WHERE source='%s' AND active=true
EOF


# dovecot config

cat > /etc/dovecot/conf.d/01-mail-stack-delivery.conf << EOF
# Some general options
protocols = imap sieve
ssl = yes
ssl_cert = </etc/ssl/private/ssl-mail.pem
ssl_key = </etc/ssl/private/ssl-mail.key
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
password_query = SELECT email as user, password FROM user WHERE email='%u';
EOF


# start Postfix and its related services.
service rsyslog start
service opendkim start
service spamassassin start
service spamass-milter start
service clamav-daemon start
service clamav-milter start
service postfix start
dovecot
sleep 3
tail -f /var/log/mail.log
