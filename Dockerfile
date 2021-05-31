FROM ubuntu:20.04

# environment variables
ENV NAGIOS_HOME            /opt/nagios
ENV NAGIOS_USER            nagios
ENV NAGIOS_GROUP           nagios
ENV NAGIOS_ADMIN_USER      nagiosadmin
ENV NAGIOS_ADMIN_PASS      nagios.1234
ENV NAGIOS_VERSION         4.4.6
ENV PLUGINS_VERSION        2.3.3
ENV DEBIAN_FRONTEND        noninteractive
ENV APACHE_RUN_USER        nagios
ENV APACHE_RUN_GROUP       nagios

# install nagios dependencies
RUN apt update && \
    apt install -y \
    build-essential \
    apache2 \
    php \
    openssl \
    perl \
    make \
    php-gd \
    libgd-dev \
    libapache2-mod-php \
    libperl-dev \
    libssl-dev \
    daemon \
    curl \
    apache2-utils \
    unzip \
    runit \
    parallel && \
    rm -rf /var/lib/apt/lists/*

# setup users
RUN groupadd ${NAGIOS_GROUP}
RUN useradd --system -d ${NAGIOS_HOME} -g ${NAGIOS_GROUP} ${NAGIOS_USER}

# build and install nagios
RUN curl -L https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-${NAGIOS_VERSION}/nagios-${NAGIOS_VERSION}.tar.gz | tar zx && \
    cd nagios-${NAGIOS_VERSION} && \
    ./configure \
    --prefix=${NAGIOS_HOME} \
    --exec-prefix=${NAGIOS_HOME} \
    --enable-event-broker && \
    make all && \ 
    make install && \
    make install-init && \
    make install-config && \
    make install-commandmode && \
    make install-webconf && \
    cd .. && rm -rf nagios-${NAGIOS_VERSION}

# build and install nagios-plugins
RUN curl -L https://github.com/nagios-plugins/nagios-plugins/releases/download/release-${PLUGINS_VERSION}/nagios-plugins-${PLUGINS_VERSION}.tar.gz | tar zx && \
    cd nagios-plugins-${PLUGINS_VERSION} && \
    ./configure --prefix=${NAGIOS_HOME} && \
    make && \
    make install && \
    cd .. && rm -rf nagios-plugins-${PLUGINS_VERSION}

# cerate the nagios admin user
RUN htpasswd -c -b ${NAGIOS_HOME}/etc/htpasswd.users ${NAGIOS_ADMIN_USER} ${NAGIOS_ADMIN_PASS}

# fix apache envs and enable CGI
RUN sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars
RUN ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load

# copy extra files
ADD extra /

# fix permissions
RUN chmod +x /usr/local/bin/start-nagios && \
    chmod +x /etc/sv/apache/run && \
    chmod +x /etc/sv/nagios/run

# enable all runit services
RUN ln -s /etc/sv/* /etc/service

# expose apache port
EXPOSE 80

# volumes
VOLUME "${NAGIOS_HOME}/var" "${NAGIOS_HOME}/etc" "/var/log/apache2"

# start nagios
CMD [ "/usr/local/bin/start-nagios" ]
