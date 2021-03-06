# =============================================================================
# ambielecki/mobilefuse-base-box
#
# CentOS-7, Apache 2.4, PHP 7.2, MYSQL
#
# =============================================================================
FROM centos:centos7

MAINTAINER andrewb <andrewb@mobilefuse.com>

ARG uid=1000
ARG gid=1000

RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
	&& rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

# ------------------------------A-----------------------------------------------
# Apache + PHP
# -----------------------------------------------------------------------------
RUN	yum -y update \
	&& yum install -y --nogpgcheck \
	awscli \
	fontconfig \
	gcc \
	gcc-c++ \
	htop \
	httpd \
	libreoffice \
	mlocate \
	mod_ssl \
	mysql-server \
	nano \
	pbzip2 \
	php72w \
	php72w-cli \
	php72w-devel \
	php72w-gd \
	php72w-json \
	php72w-mcrypt \
	php72w-mbstring \
	php72w-mysqlnd \
	php72w-pdo \
	php72w-pear \
	php72w-pecl-apcu \
	php72w-mbstring \
	php72w-soap \
	php72w-xml \
	php72w-zip \
	pigz \
	unzip \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Install composer
# -----------------------------------------------------------------------------

RUN curl https://getcomposer.org/installer > composer-setup.php
RUN php composer-setup.php --install-dir /usr/bin --filename=composer
RUN rm -f composer-setup.php

# -----------------------------------------------------------------------------
# Install updated nodejs
# -----------------------------------------------------------------------------

RUN curl --silent --location https://rpm.nodesource.com/setup_8.x | bash -
RUN yum -y install nodejs

# -----------------------------------------------------------------------------
# UTC Timezone & Networking
# -----------------------------------------------------------------------------
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
	&& echo "NETWORKING=yes" > /etc/sysconfig/network

# -----------------------------------------------------------------------------
# Global Apache configuration changes
# Disable Apache directory indexes
# Disable Apache language based content negotiation
# Disable all Apache modules and enable the minimum
# Enable ServerStatus access via /_httpdstatus to local client
# Apache tuning
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^ServerSignature On$~ServerSignature Off~g' \
	-e 's~^ServerTokens OS$~ServerTokens Prod~g' \
	-e 's~^DirectoryIndex \(.*\)$~DirectoryIndex \1 index.php~g' \
	-e 's~^Group apache$~Group app~g' \
	-e 's~^IndexOptions \(.*\)$~#IndexOptions \1~g' \
	-e 's~^IndexIgnore \(.*\)$~#IndexIgnore \1~g' \
	-e 's~^AddIconByEncoding \(.*\)$~#AddIconByEncoding \1~g' \
	-e 's~^AddIconByType \(.*\)$~#AddIconByType \1~g' \
	-e 's~^AddIcon \(.*\)$~#AddIcon \1~g' \
	-e 's~^DefaultIcon \(.*\)$~#DefaultIcon \1~g' \
	-e 's~^ReadmeName \(.*\)$~#ReadmeName \1~g' \
	-e 's~^HeaderName \(.*\)$~#HeaderName \1~g' \
	-e 's~^LanguagePriority \(.*\)$~#LanguagePriority \1~g' \
	-e 's~^ForceLanguagePriority \(.*\)$~#ForceLanguagePriority \1~g' \
	-e 's~^AddLanguage \(.*\)$~#AddLanguage \1~g' \
	-e '/#<Location \/server-status>/,/#<\/Location>/ s~^#~~' \
	-e '/<Location \/server-status>/,/<\/Location>/ s~Allow from .example.com~Allow from localhost 127.0.0.1~' \
	-e 's~^StartServers \(.*\)$~StartServers 3~g' \
	-e 's~^MinSpareServers \(.*\)$~MinSpareServers 3~g' \
	-e 's~^MaxSpareServers \(.*\)$~MaxSpareServers 3~g' \
	-e 's~^ServerLimit \(.*\)$~ServerLimit 10~g' \
	-e 's~^MaxClients \(.*\)$~MaxClients 10~g' \
	-e 's~^MaxRequestsPerChild \(.*\)$~MaxRequestsPerChild 1000~g' \
	/etc/httpd/conf/httpd.conf

RUN sed -i \
	-e 's~^\(LoadModule .*\)$~#\1~g' \
	/etc/httpd/conf.modules.d/00-dav.conf

RUN sed -i \
	-e 's~^\(LoadModule .*\)$~#\1~g' \
	/etc/httpd/conf.modules.d/00-lua.conf

RUN sed -i \
	-e 's~^\(LoadModule .*\)$~#\1~g' \
	/etc/httpd/conf.modules.d/00-proxy.conf

# -----------------------------------------------------------------------------
# Disable the default SSL Virtual Host
# -----------------------------------------------------------------------------
RUN sed -i \
	-e '/<VirtualHost _default_:443>/,/#<\/VirtualHost>/ s~^~#~' \
	/etc/httpd/conf.d/ssl.conf

# -----------------------------------------------------------------------------
# Limit process for the application user
# -----------------------------------------------------------------------------
RUN { \
		echo ''; \
		echo $'apache\tsoft\tnproc\t30'; \
		echo $'apache\thard\tnproc\t50'; \
		echo $'app\tsoft\tnproc\t30'; \
		echo $'app\thard\tnproc\t50'; \
	} >> /etc/security/limits.conf

# -----------------------------------------------------------------------------
# Global PHP configuration changes
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^;date.timezone =$~date.timezone = UTC~g' \
	-e 's~^;user_ini.filename =$~user_ini.filename =~g' \
	-e 's~^; max_input_vars.*$~max_input_vars = 4000~g' \
	-e 's~^;always_populate_raw_post_data = -1$~always_populate_raw_post_data = -1~g' \
	-e 's~^upload_max_filesize.*$~upload_max_filesize = 8M~g' \
	-e 's~^post_max_size.*$~post_max_size = 12M~g' \
	/etc/php.ini

# -----------------------------------------------------------------------------
# Add default service users
# -----------------------------------------------------------------------------
RUN if ! grep -q ":${gid}:" /etc/group;then groupadd -g ${gid} app;fi
RUN useradd -u ${uid} -d /var/www/app -m -g ${gid} app \
	&& usermod -a -G ${gid} apache

# -----------------------------------------------------------------------------
# Set default environment variables used to identify the service container
# -----------------------------------------------------------------------------
ENV SERVICE_UNIT_APP_GROUP app-1
ENV	SERVICE_UNIT_LOCAL_ID 1
ENV	SERVICE_UNIT_INSTANCE 1

# -----------------------------------------------------------------------------
# Set default environment variables used to configure the service container
# -----------------------------------------------------------------------------
ENV APACHE_SERVER_ALIAS ""
ENV	APACHE_SERVER_NAME app-1.local
ENV	APP_HOME_DIR /var/www/app
ENV	DATE_TIMEZONE UTC
ENV	HTTPD /usr/sbin/httpd
ENV	SERVICE_USER app
ENV	SERVICE_USER_GROUP app
ENV	SERVICE_USER_PASSWORD ""
ENV	SUEXECUSERGROUP false
ENV	TERM xterm
ENV DB_MYSQL_PORT_3306_TCP_ADDR ""
ENV DB_MYSQL_PORT_3306_TCP_PORT ""

# -----------------------------------------------------------------------------
# Set locale
# -----------------------------------------------------------------------------
RUN localedef -i en_US -f UTF-8 en_US.UTF-8
ENV LANG en_US.UTF-8

# -----------------------------------------------------------------------------
# Set ports
# -----------------------------------------------------------------------------
EXPOSE 80 443

CMD ["/usr/sbin/httpd", "-DFOREGROUND"]