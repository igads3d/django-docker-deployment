#!/bin/sh

python /opt/services/emptyproject/emptyproject/manage.py makemigrations
python /opt/services/emptyproject/emptyproject/manage.py migrate