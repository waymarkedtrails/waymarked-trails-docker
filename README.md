__WARNING: This docker image is no longer maintained and does not work with the current
version of waymarkedtrails.__

# Docker environment for Waymarked Trails

[Docker](https://docker.com) is a virtualized environment that allows you to run
software without altering your system permanently. The software runs in so
called containers that are easy to setup and tear down. It makes setting up a
development environment for Waymarked Trails much easier. The development
environment consists of a container with a PostgreSQL database to store the data
and a container with Python/CherryPy and NginX to preview the site.

## Prerequisites

Docker is available for Linux, macOS and Windows.
[Install](https://www.docker.com/get-docker) the software in order to be able to
run Docker containers. You also need Docker Compose, which should be available
once you installed Docker itself. Otherwise you need to
[install Docker Compose manually](https://docs.docker.com/compose/install/).

You will need at least:

* Docker Engine >= 17.04
* Docker Compose >= 1.12.0

All instructions below assume that you have cloned the
[waymarked-trails-site](https://github.com/waymarkedtrails/waymarked-trails-site)
repository to a local directory.

## Quick start

If you are eager to get started here is an overview over the necessary steps.
Read on below to get the details.

* Download OpenStreetMap data in osm.pbf format to a file `data.osm.pbf` and
place it within a defined data import directory.
* `docker-compose up waymarkedtrails` to run web and app server (the first time
data will be imported and depending on your configuration
TLS information might be generated)
* Ctrl+C to stop the web and app server
* `docker-compose stop db` to stop the database container

## Importing data

Waymarked Trails needs a database populated with OSM data to work. You first
need a data file to import. It's probably easiest to grab an PBF of OSM data
from [Geofabrik](http://download.geofabrik.de/). Once you have that file put it
into the directory `data/import/`. Data is imported the first time you
run `docker-compose up waymarkedtrails` (see below). This starts the PostgreSQL
container (downloads it if it not exists) and starts a container that runs the
necessary scripts to populate the database and then starts the app server. If
you later on want to re-import data you have to delete the existing database
first: `docker rm waymarkedtrailsdocker_db_1`. On the next start of the
`waymarkedtrails` container data will be imported again.

## Running the site

For waymarkedtrails you need a local configuration file which is placed in
`config/local.py`. It should contain the following:

```
TILE_CACHE = ''
TILE_BASE_URL = 'https://tile.waymarkedtrails.org'
DB_USER = 'postgres'
DB_RO_USER = 'postgres'
```

## Extend the docker-compose configuration

Optionally you can extend the docker-compose configuration by creating a
`docker-compose.override.yml` file and adjusting it to your needs as
explained in the
[Docker documentation](https://docs.docker.com/compose/extends/). At least you
will have to adjust the section where the waymarked-trails-site repository is
mounted into the container and the location of the data import directory if
their location on your disk deviates from where you run `docker-compose`.

```
volumes:
[...]
- type: bind
  source: ../waymarked-trails-site
  target: /waymarkedtrails
- type: bind
  source: ../data/import
  target: /import
 ```

You can set the import directory for the pbf data file by adjusting the bind
mount. The data file name is set in the environment section as variable
DATAFILE.

It is recommended to create a data directory outside of the Git repository that
contains TLS key and certificate for nginX. Otherwise these are generated every
time a container is created. This is the relevant section in
`docker-compose.yml`:

```
volumes:
    # create with e.g. openssl req -newkey rsa:2048 -x509 -keyout key.pem -out server.pem -subj "/C=/ST=/L=/O=/OU=/CN=localhost/" -days 3650 -nodes
  - type: bind
    source: ../data/etc/nginx/key.pem
    target: /etc/nginx/key.pem
  - type: bind
    source: ../data/etc/nginx/server.pem
    target: /etc/nginx/server.pem
    # create with openssl dhparam -out dh2048.pem 2048
  - type: bind
    source: ../data/etc/nginx/dh2048.pem
    target: /etc/nginx/dh2048.pem
[...]
```

The port is configurable as well.

## Startup the site

After that you run `docker-compose up waymarkedtrails`.
This starts a container with nginX/CherryPy and also starts the PostgreSQL
database container if it is not already running. The container checks if there
is a database available and if not it imports data (see above). It also checks
if TLS key, certificate and DH parameters are present and generates them
otherwise.

After startup is complete you can browse to
[https://localhost](https://localhost) to view the site. You might have to add
an exception for your browser since this is a self signed certificate. By
pressing Ctrl+C on the command line you can stop the container. The PostgreSQL
database container is still running then (you can check with `docker ps`). If
you want to stop the database container as well you can do so by running
`docker-compose stop db`.
