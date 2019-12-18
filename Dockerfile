FROM alpine:3.10

# Refs:
# https://github.com/nginxinc/docker-nginx/blob/a973c221f6cedede4dab3ab36d18240c4d3e3d74/mainline/alpine/Dockerfile
# https://hg.nginx.org/pkg-oss/file/1.17.6-1/alpine/Makefile#l214

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV NGINX_VERSION 1.17.6
ENV NJS_VERSION   0.3.7
ENV PKG_RELEASE   1

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apk add --no-cache --virtual .build-deps \
        git \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        libxslt-dev \
        gd-dev \
        geoip-dev \
        perl-dev \
        libedit-dev \
        mercurial \
        bash \
        alpine-sdk \
        findutils \
        && mkdir -p /usr/src \
        && cd /usr/src \
        && mkdir nginx-upsync \
        && git clone --single-branch --branch v1.2.1 https://github.com/xiaokai-wang/nginx-stream-upsync-module.git nginx-upsync/nginx-stream-upsync-module \
        && git clone --single-branch --branch v2.1.1 https://github.com/weibocom/nginx-upsync-module.git nginx-upsync/nginx-upsync-module \
        && curl https://raw.githubusercontent.com/CallMeFoxie/nginx-upsync/d147d4e42ad53033a4cc45c65e3c5940ea8770a0/config --output nginx-upsync/config \
       && hg clone https://hg.nginx.org/pkg-oss /usr/src/pkg-oss \
       && tempDir="$(mktemp -d)" \
       && apkArch="$(cat /etc/apk/arch)" \
       && nginxPackages=" \
           nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
           nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
           nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
           nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
           nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${PKG_RELEASE} \
        " \
        && chown -R nobody:nobody /usr/src \
        && chown nobody:nobody $tempDir \
        && su nobody -s /bin/sh -c " \
            export HOME=${tempDir} \
            && cd ${tempDir} \
            && mv /usr/src/pkg-oss pkg-oss \
            && cd pkg-oss \
            && hg up ${NGINX_VERSION}-${PKG_RELEASE} \
            && cd alpine \
            && sed -i 's/BASE_CONFIGURE_ARGS=/override BASE_CONFIGURE_ARGS+=/' Makefile \
            && make all BASE_CONFIGURE_ARGS='--add-module=/usr/src/nginx-upsync --with-stream' \
            && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
            && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
            " \
        && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
        && apk del .build-deps \
        && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n /usr/src ]; then rm -rf /usr/src; fi \
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -n "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
    && if [ -n "/etc/apk/keys/nginx_signing.rsa.pub" ]; then rm -f /etc/apk/keys/nginx_signing.rsa.pub; fi \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Bring in tzdata so users could set the timezones through the environment
# variables
    && apk add --no-cache tzdata \
# forward request and error logs to docker log collector
    && mkdir -p /var/log/nginx/ \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
