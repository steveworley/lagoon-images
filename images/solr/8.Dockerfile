ARG IMAGE_REPO
FROM ${IMAGE_REPO:-lagoon}/commons as commons
FROM solr:8.7.0-slim

LABEL maintainer="amazee.io"
ENV LAGOON=solr

ARG LAGOON_VERSION
ENV LAGOON_VERSION=$LAGOON_VERSION

ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /sbin/tini

# Copy commons files
COPY --from=commons /lagoon /lagoon
COPY --from=commons /bin/fix-permissions /bin/ep /bin/docker-sleep /bin/
# COPY --from=commons /sbin/tini /sbin/
COPY --from=commons /home/.bashrc /home/.bashrc

ENV TMPDIR=/tmp \
    TMP=/tmp \
    HOME=/home \
    # When Bash is invoked via `sh` it behaves like the old Bourne Shell and sources a file that is given in `ENV`
    ENV=/home/.bashrc \
    # When Bash is invoked as non-interactive (like `bash -c command`) it sources a file that is given in `BASH_ENV`
    BASH_ENV=/home/.bashrc

# we need root for the fix-permissions to work
USER root

# needed to fix dash upgrade - man files are removed from slim images
RUN set -x \
    && mkdir -p /usr/share/man/man1 \
    && touch /usr/share/man/man1/sh.distrib.1.gz

# replace default dash shell with bash to allow for bashisms
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

RUN chmod +x /sbin/tini
RUN mkdir -p /var/solr/data
RUN mkdir -p /opt/solr/server/solr/mycores
RUN fix-permissions /var/solr \
    && chown solr:solr /var/solr

# solr really doesn't like to be run as root, so we define the default user agin
USER solr

COPY 10-solr-port.sh /lagoon/entrypoints/
COPY 20-solr-datadir.sh /lagoon/entrypoints/

# Define Volume so locally we get persistent cores
VOLUME /var/solr

RUN precreate-core mycore

ENTRYPOINT ["/sbin/tini", "--", "/lagoon/entrypoints.sh"]

CMD ["solr-foreground"]
