#! /bin/bash
#
# Print some information about our container 
echo "$(fwconsole -V | awk -F' - ' '{print $2}') built at $(cat /build-date) with $(asterisk -V)"

# Enforce two arguments to be provided for the build process to function
if [ -z "${AMPDBPASS}" ]; then echo "AMPDBPASS env var is required but not set"; exit 1; fi
if [ -z "${AMPDBHOST}" ]; then echo "AMPDBHOST env var is required but not set"; exit 1; fi
if [ -z "${AMPDBUSER}" ]; then export AMPDBUSER="freepbxuser"; fi
if [ -z "${AMPDBPORT}" ]; then export AMPDBPORT="3306"; fi
if [ -z "${AMPDBNAME}" ]; then export AMPDBNAME="asterisk"; fi
if [ -z "${AMPDBENGINE}" ]; then export AMPDBENGINE="mysql"; fi
if [ -z "${DATASOURCE}" ]; then export DATASOURCE=""; fi

# Set the permissions for the remote mysql database
#RUN apt-get install -y mariadb-client-core
#RUN mysql -u root -h ${AMPDBHOST} -e "ALTER USER '${AMPDBUSER}'@'%' IDENTIFIED BY '${AMPDBPASS}'" && \
#    mysql -u root -h ${AMPDBHOST} -e "FLUSH PRIVILEGES;"

# Start configuring with environment variables
(echo "<?php"
 echo "// This file was generated at $(date --utc "+%Y-%m-%dT%H:%M:%S%z") by the container entrypoint"
 echo '$amp_conf["AMPDBUSER"] = "'${AMPDBUSER}'";'
 echo '$amp_conf["AMPDBPASS"] = "'${AMPDBPASS}'";'
 echo '$amp_conf["AMPDBHOST"] = "'${AMPDBHOST}'";'
 echo '$amp_conf["AMPDBPORT"] = "'${AMPDBPORT}'";'
 echo '$amp_conf["AMPDBNAME"] = "'${AMPDBNAME}'";'
 echo '$amp_conf["AMPDBENGINE"] = "'${AMPDBENGINE}'";'
 echo '$amp_conf["datasource"] = "'${DATASOURCE}'";'
 echo "require_once('/var/www/html/admin/bootstrap.php');"
 echo "?>") > /etc/freepbx.conf

# Start apache
echo "Running apache"
mkdir -p /var/log/apache2/
apachectl start

# Start redis
echo "Running redis"
mkdir -p /var/log/redis
su - redis -s /bin/bash -c "/usr/bin/redis-server --bind 127.0.0.1 --port 6379" &

# Create the mysql forwarding socket
echo "Creating socket"
socat UNIX-LISTEN:/var/run/mysqld/mysqld.sock,fork TCP:${AMPDBHOST}:${AMPDBPORT} &

# Start asterisk
echo "Running asterisk"
mkdir -p /var/log/asterisk
su - asterisk -c "/usr/sbin/asterisk -q -f -U asterisk -G asterisk -g -c" > /var/log/asterisk/asterisk.log 2>&1 &

# Wait until the asterisk socket actually exists
echo "Waiting for asterisk to be ready"
until asterisk -rx 'core show version' > /dev/null 2>&1 ; do 
	sleep 1
done

# Start freepbx
fwconsole start --skipchown --no-interaction --quiet

# Display the MOTD
fwconsole motd

# Output log to STDOUT
tail -f /var/log/asterisk/{freepbx,asterisk}.log
