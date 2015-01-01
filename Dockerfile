FROM ubuntu
MAINTAINER John Paul Alcala jp@jpalcala.com

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
        mail-stack-delivery ca-certificates opendkim opendkim-tools \
        dovecot-mysql postfix-mysql spamass-milter pyzor razor \
        libmail-dkim-perl clamav-milter arj bzip2 cabextract cpio file gzip \
        lzop nomarch p7zip pax rpm unzip zip zoo

# setup self-signed SSL certificate
RUN openssl req \
        -nodes \
        -x509 \
        -newkey rsa:4096 \
        -keyout /etc/ssl/private/ssl-mail.key \
        -out /etc/ssl/private/ssl-mail.pem \
        -subj "/C=PH/ST=NCR/L=NCR/O=example.com/OU=example.com/CN=example.com" && \
    chown root:root /etc/ssl/private/ssl-mail.* && \
    chmod 400 /etc/ssl/private/ssl-mail.*

# Environment variables for configuring Postfix at runtime.
ENV myhostname docker.example.com
ENV smtpd_helo_restrictions permit_mynetworks, reject_non_fqdn_helo_hostname, reject_invalid_helo_hostname, reject_unknown_helo_hostname, permit
#ENV smtpd_helo_restrictions permit_sasl_authenticated, permit_mynetworks
ENV smtpd_recipient_restrictions reject_unknown_sender_domain, reject_unknown_recipient_domain, reject_unauth_pipelining, permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination, reject_invalid_hostname, reject_non_fqdn_sender
ENV db_host postfixdb
ENV db_user root
ENV db_password password
ENV db_name postfix

# Main postfix configuration
RUN postconf -e 'mydestination = localhost' && \
    postconf -e 'smtpd_banner = $myhostname ESMTP' && \
    postconf -e 'smtpd_helo_required = yes' && \
    postconf -e 'smtpd_sender_restrictions = reject_unknown_sender_domain, reject_sender_login_mismatch' && \
    postconf -e 'smtpd_sender_login_maps = $virtual_mailbox_maps' && \
    postconf -e 'unknown_address_reject_code = 550' && \
    postconf -e 'unknown_hostname_reject_code = 550' && \
    postconf -e 'unknown_client_reject_code = 550' && \
    postconf -e 'smtpd_tls_ask_ccert = yes' && \
    postconf -e 'smtpd_tls_cert_file = /etc/ssl/private/ssl-mail.pem' && \
    postconf -e 'smtpd_tls_key_file = /etc/ssl/private/ssl-mail.key' && \
    postconf -e 'smtpd_tls_CAfile = /etc/ssl/certs/ca-certificates.crt' && \
    postconf -e 'smtpd_tls_ciphers = high' && \
    postconf -e 'smtpd_tls_loglevel = 1' && \
    postconf -e 'smtpd_tls_security_level = may' && \
    postconf -e 'smtpd_tls_session_cache_timeout = 3600s' && \
    postconf -e 'message_size_limit = 30720000' && \
    postconf -e 'virtual_transport = dovecot' && \
    postconf -e 'dovecot_destination_recipient_limit = 1' && \
    postconf -e 'default_destination_concurrency_limit = 5' && \
    postconf -e 'disable_vrfy_command = yes' && \
    postconf -e 'relay_destination_concurrency_limit = 1' && \
    postconf -e 'smtp_tls_note_starttls_offer = yes' && \
    postconf -e 'smtp_tls_security_level = may' && \
    postconf -e 'virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf' && \
    postconf -e 'virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf' && \
    postconf -e 'virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf'

COPY etc/postfix/master.cf /etc/postfix/

# Dovecot configuration
RUN groupadd -g 5000 vmail && \
    useradd -g vmail -u 5000 vmail -d /var/mail/vmail -m

COPY etc/dovecot/conf.d/* /etc/dovecot/conf.d/

# OpenDKIM configuration
RUN mkdir /etc/opendkim && \
    chown opendkim:opendkim /etc/opendkim

COPY etc/opendkim.conf /etc/
RUN mkdir /var/spool/postfix/opendkim && \
    chown opendkim:root /var/spool/postfix/opendkim
RUN usermod -G opendkim postfix

# Spamassassin configuration
RUN adduser \
        --shell /bin/false \
        --home /var/lib/spamassassin \
        --disabled-password \
        --disabled-login \
        --gecos "" \
        spamd && \
    usermod -a -G spamd spamass-milter && \
    chown -R spamd:spamd /var/lib/spamassassin

COPY etc/default/* /etc/default/

RUN mkdir /var/spool/postfix/spamassassin && \
    chown spamd:root /var/spool/postfix/spamassassin/

COPY etc/spamassassin/* /etc/spamassassin/

RUN spamassassin --lint
RUN mkdir -p /var/lib/spamassassin/.spamassassin

RUN mkdir -p /var/lib/spamassassin/.razor && \
    mkdir /var/lib/spamassassin/.pyzor
RUN pyzor --homedir /var/lib/spamassassin/.pyzor discover
RUN razor-admin -home=/var/lib/spamassassin/.razor -register && \
    razor-admin -home=/var/lib/spamassassin/.razor -create && \
    razor-admin -home=/var/lib/spamassassin/.razor -discover
RUN echo "razorhome = /var/lib/spamassassin/.razor" >> /var/lib/spamassassin/.razor/razor-agent.conf

RUN chown -R spamd:spamd /var/lib/spamassassin

# Tell postfix about the milters
RUN postconf -e 'milter_default_action = accept' && \
    postconf -e 'milter_connect_macros = j {daemon_name} v {if_name} _' && \
    postconf -e 'non_smtpd_milters = $smtpd_milters' && \
    postconf -e 'smtpd_milters = unix:/spamass/spamass.sock unix:/clamav/clamav-milter.ctl unix:/opendkim/opendkim.sock'

# Clamav configuration
COPY etc/clamav/* /etc/clamav/

RUN mkdir /var/spool/postfix/clamav && \
    chown clamav:root /var/spool/postfix/clamav/

RUN freshclam

# Sieve configuration
RUN mkdir /var/mail/vmail/sieve-before && \
    mkdir /var/mail/vmail/sieve-after

COPY var/mail/vmail/sieve-before/*.sieve /var/mail/vmail/sieve-before/

RUN sievec /var/mail/vmail/sieve-before/*.sieve && \
    chown -R vmail:vmail /var/mail/vmail

# Postscreen configuration
RUN postconf -e 'postscreen_greet_action = enforce' && \
    postconf -e 'postscreen_dnsbl_action = enforce' && \
    postconf -e 'postscreen_access_list = permit_mynetworks' && \
    postconf -e 'postscreen_dnsbl_sites = zen.spamhaus.org, b.barracudacentral.org, bl.spamcop.net'

# Run script
COPY postfix.sh /opt/

VOLUME ["/etc/ssl", "/etc/opendkim", "/etc/postfix", "/etc/dovecot", "/etc/spamassassin", "/etc/default", "/etc/clamav", "/var/mail", "/var/lib/spamassassin", "/var/lib/clamav", "/var/log"]

EXPOSE 25 143 993 587

WORKDIR /
CMD ["/opt/postfix.sh"]
