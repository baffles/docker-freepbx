FROM debian:buster
LABEL maintainer="Robert Ferris (https://www.github.com/baffles/)"

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm

### Set Defaults
ENV S6_OVERLAY_VERSION=v1.22.1.0 \
    ASTERISK_VERSION=16.10.0 \
    FREEPBX_VERSION=15.0.16.55 \
    BCG729_VERSION=1.0.4 \
    SPANDSP_VERSION=20180108 \
    DB_EMBEDDED=TRUE \
    UCP_FIRST=TRUE

### Pin libxml2 packages to Debian repositories
RUN echo "Package: libxml2*" > /etc/apt/preferences.d/libxml2 && \
    echo "Pin: release o=Debian,n=buster" >> /etc/apt/preferences.d/libxml2 && \
    echo "Pin-Priority: 501" >> /etc/apt/preferences.d/libxml2

RUN \
### Base dependencies
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        aptitude \
        bash \
        ca-certificates \
        curl \
        gnupg \
        && \
### S6 Overlay
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-armhf.tar.gz | tar xfz - --strip 0 -C / && \
### Install Dependencies
    set -x && \
    curl https://packages.sury.org/php/apt.gpg | apt-key add - && \
    curl https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
    echo "deb https://packages.sury.org/php/ buster main" > /etc/apt/sources.list.d/deb.sury.org.list && \
    echo "deb https://deb.nodesource.com/node_12.x buster main" > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update  && \
    apt-get -o Dpkg::Options::="--force-confold" upgrade -y && \
    \
### Install Development Dependencies
    \
    ASTERISK_BUILD_DEPS='\
                        autoconf \
                        automake \
                        bison \
                        build-essential \
                        doxygen \
                        flex \
                        libasound2-dev \
                        libcurl4-openssl-dev \
                        libedit-dev \
                        libical-dev \
                        libiksemel-dev \
                        libjansson-dev \
                        libmariadbclient-dev \
                        libncurses5-dev \
                        libneon27-dev \
                        libnewt-dev \
                        libogg-dev \
                        libresample1-dev \
                        libspandsp-dev \
                        libsqlite3-dev \
                        libsrtp2-dev \
                        libssl-dev \
                        libtiff-dev \
                        libtool-bin \
                        libvorbis-dev \
                        libxml2-dev \
                        python-dev \
                        subversion \
                        unixodbc-dev \
                        uuid-dev \
                        ' && \
    \
### Install Runtime Dependencies
    apt-get install --no-install-recommends -y \
                    $ASTERISK_BUILD_DEPS \
                    apache2 \
                    composer \
                    fail2ban \
                    flite \
                    ffmpeg \
                    git \
                    g++ \
                    iptables \
                    lame \
                    libiodbc2 \
                    libicu63 \
                    libicu-dev \
                    libsrtp2-1 \
                    locales \
                    locales-all \
                    logrotate \
                    mariadb-client \
                    mariadb-server \
                    mpg123 \
                    nodejs \
                    php5.6 \
                    php5.6-cli \
                    php5.6-curl \
                    php5.6-gd \
                    php5.6-ldap \
                    php5.6-mbstring \
                    php5.6-mysql \
                    php5.6-sqlite \
                    php5.6-xml \
                    php5.6-zip \
                    php5.6-intl \
                    php-pear \
                    pkg-config \
                    sipsak \
                    sngrep \
                    sox \
                    sqlite3 \
                    tcpdump \
                    tcpflow \
                    unixodbc \
                    uuid \
                    wget \
                    whois \
                    xmlstarlet \
                    && \
    \
### Install Legacy MySQL ODBC Connector
    printf "Package: *\nPin: release n=stretch\nPin-Priority: 900\nPackage: *\nPin: release n=jessie\nPin-Priority: 100" >> /etc/apt/preferences.d/jessie && \
#    echo "deb http://mirrordirector.raspbian.org/raspbian/ jessie main contrib" >> /etc/apt/sources.list && \
    echo "deb http://raspbian.mirror.constant.com/raspbian/ jessie main contrib" >> /etc/apt/sources.list && \
    curl -s http://archive.raspbian.org/raspbian.public.key | apt-key add - && \
    apt-get update && \
    apt-get -y --allow-unauthenticated install libmyodbc && \
    sed '$d' /etc/apt/sources.list > /etc/apt/sources.list && \
    rm /etc/apt/preferences.d/jessie && \
    apt-get update && \
### Add Users
    addgroup --gid 2600 asterisk && \
    adduser --uid 2600 --gid 2600 --gecos "Asterisk User" --disabled-password asterisk && \
    \
### Build SpanDSP
    mkdir -p /usr/src/spandsp && \
    curl -kL http://sources.buildroot.net/spandsp/spandsp-${SPANDSP_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/spandsp && \
    cd /usr/src/spandsp && \
    ./configure && \
    make && \
    make install && \
    \
### Build Asterisk
    cd /usr/src && \
    mkdir -p asterisk && \
    curl -sSL http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz | tar xvfz - --strip 1 -C /usr/src/asterisk && \
    cd /usr/src/asterisk/ && \
    make distclean && \
    contrib/scripts/get_mp3_source.sh && \
    ./configure --with-resample --with-pjproject-bundled --with-jansson-bundled --with-ssl=ssl --with-srtp && \
    make menuselect/menuselect menuselect-tree menuselect.makeopts && \
    menuselect/menuselect --disable BUILD_NATIVE \
                          --enable app_confbridge \
                          --enable app_fax \
                          --enable app_macro \
                          --enable codec_opus \
                          --enable codec_silk \
                          --enable format_mp3 \
                          --enable BETTER_BACKTRACES \
                          --disable MOH-OPSOUND-WAV \
                          --enable MOH-OPSOUND-GSM \
    make && \
    make install && \
    make install-headers && \
    make config && \
    ldconfig && \
    \
#### Add G729 Codecs
    git clone https://github.com/BelledonneCommunications/bcg729 /usr/src/bcg729 && \
    cd /usr/src/bcg729 && \
    git checkout tags/$BCG729_VERSION && \
    ./autogen.sh && \
    ./configure --libdir=/lib && \
    make && \
    make install && \
    \
    mkdir -p /usr/src/asterisk-g72x && \
    curl https://bitbucket.org/arkadi/asterisk-g72x/get/master.tar.gz | tar xvfz - --strip 1 -C /usr/src/asterisk-g72x && \
    cd /usr/src/asterisk-g72x && \
    ./autogen.sh && \
    ./configure CFLAGS='-march=armv7' --with-bcg729 --with-asterisk160 --enable-penryn && \
    make && \
    make install && \
    \
### Cleanup
    mkdir -p /var/run/fail2ban && \
    cd / && \
    rm -rf /usr/src/* /tmp/* /etc/cron* && \
    apt-get purge -y $ASTERISK_BUILD_DEPS libspandsp-dev && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    \
### FreePBX Hacks
    sed -i -e "s/memory_limit = 128M/memory_limit = 256M/g" /etc/php/5.6/apache2/php.ini && \
    sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php/5.6/apache2/php.ini && \
    a2disconf other-vhosts-access-log.conf && \
    a2enmod rewrite && \
    a2enmod headers && \
    rm -rf /var/log/* && \
    mkdir -p /var/log/asterisk && \
    mkdir -p /var/log/apache2 && \
    mkdir -p /var/log/httpd && \
    \
### Setup for Data Persistence
    mkdir -p /assets/config/var/lib/ /assets/config/home/ && \
    mv /home/asterisk /assets/config/home/ && \
    ln -s /data/home/asterisk /home/asterisk && \
    mv /var/lib/asterisk /assets/config/var/lib/ && \
    ln -s /data/var/lib/asterisk /var/lib/asterisk && \
    ln -s /data/usr/local/fop2 /usr/local/fop2 && \
    mkdir -p /assets/config/var/run/ && \
    mv /var/run/asterisk /assets/config/var/run/ && \
    mv /var/lib/mysql /assets/config/var/lib/ && \
    mkdir -p /assets/config/var/spool && \
    mkdir -p /var/spool/cron && \
    mv /var/spool/cron /assets/config/var/spool/ && \
    ln -s /data/var/spool/cron /var/spool/cron && \
    ln -s /data/var/run/asterisk /var/run/asterisk && \
    rm -rf /var/spool/asterisk && \
    ln -s /data/var/spool/asterisk /var/spool/asterisk && \
    rm -rf /etc/asterisk && \
    ln -s /data/etc/asterisk /etc/asterisk

### Networking Configuration
EXPOSE 80 443 4445 4569 5060/udp 5160/udp 5061 5161 8001 8003 8008 8009 18000-20000/udp

### Files Add
ADD install /

ENTRYPOINT ["/init"]
