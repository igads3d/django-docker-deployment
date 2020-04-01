#!/bin/sh

cd /opt/services/emptyproject/
source /bin/activate
cd emptyproject

python manage.py makemigrations
python manage.py migrate

gunicorn --bind 0.0.0.0:80 emptyproject.wsgi