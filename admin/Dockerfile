FROM python:2.7

ENV PYTHONUNBUFFERED="1"

COPY requirements.txt /usr/src/app/

RUN pip install -r /usr/src/app/requirements.txt

COPY . /usr/src/app/

WORKDIR /usr/src/app

RUN python manage.py collectstatic --no-input

EXPOSE 8000

CMD ["/bin/bash", "-c", "python manage.py migrate && uwsgi --ini uwsgi.ini"]
