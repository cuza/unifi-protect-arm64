FROM arm64v8/debian:11

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y --no-install-recommends install \
        curl \
        wget \
        mount \
        psmisc \
        dpkg \
        apt \
        lsb-release \
        sudo \
        gnupg \
        apt-transport-https \
        ca-certificates \
        dirmngr \
        mdadm \
        iproute2 \
        ethtool \
        procps \
        systemd-timesyncd \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get -y --no-install-recommends install systemd \
    && find /etc/systemd/system \
        /lib/systemd/system \
        -path '*.wants/*' \
        -not -name '*journald*' \
        -not -name '*systemd-tmpfiles*' \
        -not -name '*systemd-user-sessions*' \
        -exec rm \{} \; \
    && rm -rf /var/lib/apt/lists/*
STOPSIGNAL SIGKILL

RUN curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" > /etc/apt/sources.list.d/postgresql.list \
    && apt-get update \
    && apt-get -y --no-install-recommends install postgresql-client-14 \
    && rm -rf /var/lib/apt/lists/*

#COPY put-deb-files-here/*.deb /
COPY put-version-file-here/version /usr/lib/version
COPY files/lib /lib/

RUN --mount=type=bind,target=/debs,source=put-deb-files-here,ro apt-get -y --no-install-recommends install /debs/ubnt-archive-keyring_*_arm64.deb
RUN echo 'deb https://apt.artifacts.ui.com bullseye main release beta' > /etc/apt/sources.list.d/ubiquiti.list
RUN chmod 666 /etc/apt/sources.list.d/ubiquiti.list
RUN apt-get update
RUN --mount=type=bind,target=/debs,source=put-deb-files-here,ro apt-get -o DPkg::Options::=--force-confdef -y --no-install-recommends install /debs/*.deb unifi-protect
RUN rm -f /*.deb
RUN rm -rf /var/lib/apt/lists/*
RUN echo "exit 0" > /usr/sbin/policy-rc.d
RUN sed -i "s/redirectHostname: 'unifi'//" /usr/share/unifi-core/app/config/default.yaml
RUN mv /sbin/mdadm /sbin/mdadm.orig
RUN mv /usr/sbin/smartctl /usr/sbin/smartctl.orig
RUN systemctl enable storage_disk dbpermissions loop

RUN sed -i 's/postgresql-cluster@14-main.service//' /lib/systemd/system/unifi-core.service
RUN sed -i 's/postgresql@14-protect.service//' /lib/systemd/system/unifi-protect.service && \
  sed -i 's/postgresql-cluster@14-protect.service//' /lib/systemd/system/unifi-protect.service
RUN sed -i 's/postgresql.service//' /lib/systemd/system/ulp-go.service
RUN sed -i 's/sudo .* psql/psql/' /usr/lib/ulp-go/scripts/unifi-goapp-mgnt-extension.sh && \
  sed -i 's/sudo -u postgres //' /usr/lib/ulp-go/scripts/unifi-goapp-mgnt-extension.sh && \
  sed -i 's/-U ${user}//' /usr/lib/ulp-go/scripts/unifi-goapp-mgnt-extension.sh && \
  sed -i 's/psql_dropdb/source \/data\/ulp-go.pg.sh\n\npsql_dropdb/' /usr/lib/ulp-go/scripts/unifi-goapp-mgnt-extension.sh

RUN mkdir /var/log/postgresql && ln -s /bin/true /usr/bin/pg_createcluster
RUN mv /usr/bin/pg_isready /usr/bin/pg_isready.orig && ln -s /bin/true /usr/bin/pg_isready
RUN ln -s /bin/true /usr/bin/pg_dropcluster && ln -s /bin/true /usr/bin/pg_conftool

COPY files/sbin /sbin/
COPY files/usr /usr/
COPY files/etc /etc/

VOLUME ["/srv", "/data", "/persistent"]

CMD ["/lib/systemd/systemd"]
