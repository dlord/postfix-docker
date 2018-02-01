FROM python:2.7

ENV PYTHONUNBUFFERED="1"

COPY requirements.txt /usr/src/app/

RUN pip install -r /usr/src/app/requirements.txt

COPY . /usr/src/app/

WORKDIR /usr/src/app

EXPOSE 8000

CMD ["/bin/bash", "-c", "python manage.py migrate && python manage.py runserver 0.0.0.0:8000"]
