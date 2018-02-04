# Postfix-Dovecot Server

* * *

## About this image

Dockerized Postfix, based on Ars Technica article on running your own mail server.

http://arstechnica.com/information-technology/2014/02/how-to-run-your-own-e-mail-server-with-your-own-domain-part-1/

## SSL Compliance

This image's SSL configuration tries to be compliant with the following
standards:

* PCI DSS v3.2
* HIPAA
* NIST

This image supports the following protocols:

* TLS v1.0
* TLS v1.1
* TLS v1.2

While this server aims to be as compliant with the mentioned standards, it is
also important to retain maximum compatibility with existing mail clients.

PCI DSS states that SSL v3.0 and TLS v1.0 must be disabled by June 2018.
There are some mail clients (e.g. macOS's Mail app) do not support TLS v1.1 and
above.
