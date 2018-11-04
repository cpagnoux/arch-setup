#!/bin/bash

php_configure() {
	echo "Backing up /etc/httpd/conf/httpd.conf..."
	cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak

	echo "Updating /etc/httpd/conf/httpd.conf..."
	sed -i 's/^#\(LoadModule proxy_module modules\/mod_proxy\.so\)/\1/' /etc/httpd/conf/httpd.conf
	sed -i 's/^#\(LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi\.so\)/\1/' /etc/httpd/conf/httpd.conf

	echo "Creating /etc/httpd/conf/extra/php-fpm.conf..."
	echo "<FilesMatch \.php$>" > /etc/httpd/conf/extra/php-fpm.conf
	echo '    SetHandler "proxy:unix:/run/php-fpm/php-fpm.sock|fcgi://localhost/"' >> /etc/httpd/conf/extra/php-fpm.conf
	echo "</FilesMatch>" >> /etc/httpd/conf/extra/php-fpm.conf

	echo "Updating /etc/httpd/conf/httpd.conf..."
	echo "Include conf/extra/php-fpm.conf" >> /etc/httpd/conf/httpd.conf
	echo "" >> /etc/httpd/conf/httpd.conf
}

mariadb_configure() {
	mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

	echo "Backing up /etc/php/php.ini..."
	cp /etc/php/php.ini /etc/php/php.ini.bak

	echo "Updating /etc/php/php.ini..."
	sed -i 's/^;\(extension=pdo_mysql\)/\1/' /etc/php/php.ini
	sed -i 's/^;\(extension=mysqli\)/\1/' /etc/php/php.ini
}

pacman -S apache php php-fpm composer mariadb

php_configure
mariadb_configure
