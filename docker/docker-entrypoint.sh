#!/bin/sh

cd /opt/services/emptyproject/

# i don't know if we need to activate the venv, but why not
source /bin/activate
cd emptyproject

# migrations are made at runtime
python manage.py makemigrations
python manage.py migrate

# gunicorn should be started from where your 'manage.py' is located
# in case if you are starting it from another directory, use '--chdir'
gunicorn --bind 0.0.0.0:80 emptyproject.wsgi