FROM python:2.7

ENV PYTHONUNBUFFERED="1"

COPY requirements.txt /usr/src/app/

RUN pip install -r /usr/src/app/requirements.txt

COPY . /usr/src/app/

WORKDIR /usr/src/app

EXPOSE 8000
