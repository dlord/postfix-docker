FROM ubuntu
MAINTAINER John Paul Alcala jp@jpalcala.com

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install python-pip python2.7-dev

RUN adduser \
        --shell /bin/false \
        --home /opt/pappy \
        --disabled-password \
        --disabled-login \
        --gecos "" \
        pappy

COPY requirements.txt /opt/pappy/
WORKDIR /opt/pappy
RUN pip install -r requirements.txt --allow-external mysql-connector-python

COPY *.py uwsgi.ini /opt/pappy/
COPY pappy /opt/pappy/pappy/

RUN chown -R pappy:pappy /opt/pappy

ENV db_host postfixdb
ENV db_user root
ENV db_password password
ENV db_name postfix

EXPOSE 5000

USER pappy
CMD ["/usr/local/bin/uwsgi", "--ini", "uwsgi.ini"]
