FROM debian:stretch

# set nginx user and group so that it remains consistent
RUN addgroup --gid 8080 --system nginx && adduser --uid 8080 --system --ingroup nginx nginx

# add S6 overlay so that we can manage python and nginx together
ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C / \
    && rm /tmp/s6-overlay-amd64.tar.gz

# install everything which is provided as package
RUN apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends -y \
        python3-minimal python3-setuptools python3-psycopg2 python3-shapely python3-pip \
        python3-cairo python3-gi python3-gi-cairo gir1.2-pango-1.0 gir1.2-rsvg-2.0 \
        python3-gdal python3-scipy python3-yaml python3-wheel python3-pyosmium \
        curl gzip postgresql-client nginx openssl ca-certificates locales \
    && /usr/sbin/update-locale LANG=C.UTF-8 \
    && apt-get remove -y locales \
    && rm -rf /var/lib/apt/lists/*

ENV LANG C.UTF-8

# install evertyhing else through pip
RUN pip3 install SQLAlchemy==1.0.8 GeoAlchemy2==0.2.5 SQLAlchemy-Utils \
        CherryPy==3.8.0 Babel==2.2.0 Jinja2==2.8 Markdown==2.5.1 \
        webassets==0.11.1 cssutils==1.0.1 \
    && curl -L -s https://api.github.com/repos/waymarkedtrails/osgende/tarball/master -o /root/osgende.tar.gz \
    && mkdir /root/osgende \
    && tar xzf /root/osgende.tar.gz -C /root/osgende --strip 1 \
    && pip3 install /root/osgende/ \
    && rm -rf /root/osgende \
    && rm -f /root/osgende.tar.gz

# add customized files such as configuration for nginx
COPY root /

RUN mkdir -p /waymarkedtrails
VOLUME ["/waymarkedtrails"]

EXPOSE 80 443

# we check if nginx is still returning a 200 response, else the container is unhealthy
HEALTHCHECK --interval=1m --timeout=3s \
    CMD curl -fk https://localhost/ || exit 1

# we need our own entrypoint because we might do some initializing before
# we start s6
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
