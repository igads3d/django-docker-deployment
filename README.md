# django-docker-deployment
This repo shows how one can deploy his/her Django application using Docker-compose. It's kind of **very** detailed memo on how to do all 
that stuff. 
There definitely should be a better way to do that, so if you know how to do it better, please, share your knowledge. 

## Structure
```
├── docker/
│   ├── docker-entrypoint.sh*
│   ├── Dockerfile.nginx
│   ├── Dockerfile.python
│   └── nginx.conf
├── docker-compose.yaml
├── emptyproject/
│   ├── emptyapp/
│   │   ├── admin.py
│   │   ├── apps.py
│   │   ├── __init__.py
│   │   ├── migrations/
│   │   ├── models.py
│   │   ├── tests.py
│   │   └── views.py
│   ├── emptyproject/
│   │   ├── asgi.py
│   │   ├── __init__.py
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   ├── manage.py*
│   └── static/
│       └── admin/
└──  requirements.txt
```
### docker/
This directory contains Dockerfiles, `docker-entrypoint.sh` for the "application" service and nginx configuration file.

### emptyproject/
Contains directories for main Django project and Django app; `static/` directory and `manage.py` are also here.

#### emptyapp/
Django application. Models and views are in this directory.

#### emptyproject/
Django project. Settings, urls and WSGI/ASGI settings.


### requirements.txt
Pip packages.

## How does it work
### On Django side
*For this section our working directory is `~/empty-django-app/emptyproject`*
1. Create a directory called `empty-django-app` and set up a venv by using command `python -m venv empty-django-app`
2. Set up a Django project and app, create superuser just like in tutorial
3. Make one simple view (`emptyapp/views.py`):
```python
def test(request):
	return HttpResponse("horsecock")
```
4. Add URL pattern to the list (`emptyproject/urls.py`):
```python
urlpatterns = [
    path("test/", views.test, name='test'),
    path('admin/', admin.site.urls),
]
```
5. In setings append application's name to the `INSTALLED_APPS` section (`emptyproject/settings.py`):
```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles', 
    'emptyapp',
]
```
6. In `DATABASE` section change your database engine and enter everything needed(`emptyproject/settings.py`):
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'emptyproject-db',
        'USER': 'emptyproject-user',
        'PASSWORD': 'asshole',
        'HOST': 'database',
        'PORT': '5432',
    }
}
```

### On Nginx side
Create Nginx configuration file
```
upstream application_server {
	server application:80;
}

server {

    listen 80;
    server_name emptyapp;

    location / {
        # i don't really know what headers do i need, so i pass all the common ones
        proxy_pass http://application_server;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        proxy_redirect off;
    }

    location /static/ {
        # keep in mind that 'static root' does not include the 'static/' directory;
        # by the way, it is located in `/opt/services/emptyproject/static`
        root /opt/services/emptyproject;
    }

}
```

### On PostgreSQL side
User, password and database name are configured at runtime by Docker-compose.

### On Docker/Docker-compose side
1. Create `Dockerfile.python`
```dockerfile
FROM python:3.8

# step 1 from "On Django side" section 
RUN mkdir -p /opt/services/emptyproject
WORKDIR /opt/services/
RUN python -m venv emptyproject
WORKDIR emptyproject
# now we operate in /opt/services/emptyproject 
# i probably should've been named this like 'webapp' or something

# make /opt/services/emptyproject/emptyproject/emptyproject directory. Foken hell
#         empty-django-app^   manage.py^          ^settings and urls here
RUN mkdir -p emptyproject/emptyproject

# make /opt/services/emptyproject/emptyproject/emptyapp directory
RUN mkdir -p emptyproject/emptyapp

# copy 'emptyapp/', 'emptyproject/' and `manage.py` where they are belong, don't touch 'static/'
COPY emptyproject/emptyapp emptyproject/emptyapp
COPY emptyproject/emptyproject emptyproject/emptyproject
COPY emptyproject/manage.py emptyproject

COPY requirements.txt .
RUN pip install -r requirements.txt

# copy entrypoint and do not forget about "execute" permission
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
```
2. Create `docker-entrypoint.sh`
```sh
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
```

3. Create `Dockerfile.nginx`
```dockerfile
FROM nginx

# copy static
RUN mkdir -p /opt/services/emptyproject/static
COPY emptyproject/static/ /opt/services/emptyproject/static

# copy config (keep in mind, that this is an include file, not the main config)
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
```

4. Create `docker-compose.yaml`
```yaml
# don't know why 3.1, but why not
version: '3.1'

services:

  database:
    image: postgres
    restart: always
    environment:
      POSTGRES_PASSWORD: asshole
      POSTGRES_USER: emptyproject-user
      POSTGRES_DB: emptyproject-db

  application:
    # our Dockerfiles are not located in our build context directory
    build:
      context: .
      dockerfile: docker/Dockerfile.python
    restart: always
    depends_on:
      - database
    # docker-entrypoint.sh is already inside the container
    entrypoint: /docker-entrypoint.sh

  nginx:
    build:
      context: .
      dockerfile: docker/Dockerfile.nginx
    ports:
      - 80:80
    restart: always
    depends_on:
      - application

```
### We're all set
Now, to deploy this application on any computer we just need to do following steps:
```sh
git clone https://github.com/igads3d/django-docker-deployment.git
cd django-docker-deployment
docker-compose up --build
```
That's all, Docker compose will now download and build all necessary images. Gunicorn will serve on port 80 inside the isolated network,
Nginx will listen on port 80 on the outside and pass requests to the gunicorn, that will process them. PostgreSQL uses port 5432
inside the isolated network.

For now, this is all we need to set up a *not-so-production* environment. Our app uses PostrgeSQL database, is being served through 
Nginx, but, still, there is something left to do.
