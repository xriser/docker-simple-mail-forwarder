FROM alpine:3.12
LABEL maintainer="Zhuohuan LI <zixia@zixia.net>"

ENV BATS_VERSION 1.2.1
ENV S6_VERSION 2.1.0.0

ENV SRS_DOMAIN example.com
ENV SRS_SECRET /etc/postsrsd.secret

## Install System

RUN apk add --update --no-cache \
        bash \
        curl \
        cyrus-sasl \
        cyrus-sasl-plain \
        cyrus-sasl-login \
        ca-certificates \
        drill \
        logrotate \
        openssl \
        postfix \
        syslog-ng \
        tzdata \
        opendkim \
        opendkim-utils \
        postsrsd \
        procps gawk grep sed bind-tools tar \
    && curl -s -o "/tmp/v${BATS_VERSION}.tar.gz" -L \
        "https://github.com/bats-core/bats-core/archive/v${BATS_VERSION}.tar.gz" \
    && tar -xzf "/tmp/v${BATS_VERSION}.tar.gz" -C /tmp/ \
    && bash "/tmp/bats-core-${BATS_VERSION}/install.sh" /usr/local

## Install whitelisting
ADD https://github.com/spf-tools/spf-tools/archive/v2.1.tar.gz /tmp/
RUN cd /tmp && tar xfz v2.1.tar.gz && mv spf-tools-2.1 spf-tools && mv spf-tools/ /usr/local/bin/
ADD https://github.com/stevejenkins/postwhite/archive/v3.4.tar.gz /tmp/
RUN cd /tmp && tar xfz v3.4.tar.gz && mv postwhite-3.4 postwhite && mv postwhite/ /usr/local/bin/ && cp /usr/local/bin/postwhite/postwhite.conf /etc/

## Install s6 process manager
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_VERSION}/s6-overlay-amd64.tar.gz /tmp/
RUN gunzip -c /tmp/s6-overlay-amd64.tar.gz | tar -xf - -C / && rm -rf /tmp/*

## Configure Services
COPY install/main.dist.cf /etc/postfix/main.cf
COPY install/master.dist.cf /etc/postfix/master.cf
COPY install/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
COPY install/opendkim.conf /etc/opendkim/opendkim.conf
COPY install/00postwhite /etc/periodic/daily/00postwhite
RUN chmod a+x /etc/periodic/daily/00postwhite

RUN cat /dev/null > /etc/postfix/aliases && newaliases \
    && echo simple-mail-forwarder.com > /etc/hostname \
    && mkdir -p /run/opendkim && chown opendkim:opendkim /run/opendkim \
    && echo test | saslpasswd2 -p test@test.com \
    && chown postfix /etc/sasl2/sasldb2 \
    && saslpasswd2 -d test@test.com

RUN tr -dc '1-9a-zA-Z' < /dev/random | head -c 32 > /etc/postsrsd.secret

## Copy App

WORKDIR /app

COPY install/init-openssl.sh /app/init-openssl.sh
RUN bash -n /app/init-openssl.sh && chmod +x /app/init-openssl.sh

COPY install/postfix.sh /etc/services.d/postfix/run
RUN bash -n /etc/services.d/postfix/run && chmod +x /etc/services.d/postfix/run

COPY install/syslog-ng.sh /etc/services.d/syslog-ng/run
RUN bash -n /etc/services.d/syslog-ng/run && chmod +x /etc/services.d/syslog-ng/run

COPY install/opendkim.sh /etc/services.d/opendkim/run
RUN bash -n /etc/services.d/opendkim/run && chmod +x /etc/services.d/opendkim/run
COPY install/default.private /var/db/dkim/default.private
RUN chmod 400 /var/db/dkim/default.private && chown opendkim:opendkim /var/db/dkim/default.private

COPY install/postsrsd.sh /etc/services.d/postsrsd/run
RUN bash -n /etc/services.d/postsrsd/run && chmod +x /etc/services.d/postsrsd/run

COPY install/cron.sh /etc/services.d/cron/run
RUN bash -n /etc/services.d/cron/run && chmod +x /etc/services.d/cron/run

COPY entrypoint.sh /entrypoint.sh
RUN bash -n /entrypoint.sh && chmod a+x /entrypoint.sh

COPY BANNER /app/
COPY test /app/test

COPY .git/logs/HEAD /app/GIT_LOG
COPY .git/HEAD /app/GIT_HEAD
COPY install/buildenv.sh /app/

VOLUME ["/var/spool/postfix"]

EXPOSE 25

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]


## Log Environment (in Builder)

RUN bash buildenv.sh

