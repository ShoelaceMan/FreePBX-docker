#! /bin/bash
#
# Exit on error (exit) or error (trace)
set -eE

# Define an exit function
exit_or_debug_on_error(){
    if ! [ -z "${DEBUG_ON_ERROR}" ]; then
        echo "Debug var set, hanging until /var/run/debugbreak exists."
        until [ -f "/var/run/debugbreak" ]; do
            sleep 1
        done
    fi
    exit 1
}

# Trap exits to use our function
trap 'exit_or_debug_on_error' ERR

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

# Enforce the required persistent volume existing
if ! [ -d /data ]; then echo "/data persistent volume is required but does not exist"; exit 1; fi

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

# Start configuring with static values
(echo '[FP5AQ6vmwe3j]'
 echo 'secret = JYAXPpy8KJLj'
 echo 'deny=0.0.0.0/0.0.0.0'
 echo 'permit=127.0.0.1/255.255.255.0'
 echo 'read = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate,message'
 echo 'write = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate,message'
 echo 'writetimeout = 5000'
 echo '#include manager_additional.conf'
 echo '#include manager_custom.conf') >> /etc/asterisk/manager.conf

# Start apache
echo "Running apache"
if ! [ -d "/var/log/apache2" ]; then
    echo "Creating apache2 log directory"
    mkdir "/var/log/apache2"
fi
if ! [ "$(stat -c '%U' "/var/log/apache2/")" == "asterisk" ]; then
    echo "chowning apache2 log directory"
    chown -R asterisk: "/var/log/apache2"
fi
apachectl start

# Start redis
echo "Running redis"
su - redis -s /bin/bash -c "/usr/bin/redis-server --bind 127.0.0.1 --port 6379" &

# Create the mysql forwarding socket
echo "Creating socket"
socat UNIX-LISTEN:/var/run/mysqld/mysqld.sock,fork TCP:${AMPDBHOST}:${AMPDBPORT} &

# Start asterisk
echo "Running asterisk"
if ! [ -d "/var/log/asterisk" ]; then
    echo "Creating asterisk log directory"
    mkdir "/var/log/asterisk"
fi
if ! [ "$(stat -c '%U' "/var/log/asterisk/")" == "asterisk" ]; then
    echo "chowning asterisk log directory"
    chown -R asterisk: "/var/log/asterisk"
fi
su - asterisk -c "/usr/sbin/asterisk -q -f -U asterisk -G asterisk -g -c" > /var/log/asterisk/asterisk.log 2>&1 &

# Wait until the asterisk socket actually exists
echo "Waiting for asterisk to be ready"
until asterisk -rx 'core show version' > /dev/null 2>&1 ; do 
	sleep 1
done

# Start freepbx
for freepbx_log_file in fail2ban freepbx_security.log freepbx.log; do
    if ! [ -f "/var/log/asterisk/${freepbx_log_file}" ]; then
        echo "Creating freepbx log file at ${freepbx_log_file}"
        touch "/var/log/asterisk/${freepbx_log_file}"
    fi
    if ! [ "$(stat -c '%U' "/var/log/asterisk/${freepbx_log_file}")" == "asterisk" ]; then
        echo "chowning freepbx log file at ${freepbx_log_file}"
        chown -R asterisk: "/var/log/asterisk/${freepbx_log_file}"
    fi
done
fwconsole start --no-interaction --quiet

# Display the MOTD
fwconsole motd

# Output log to STDOUT
tail -f /var/log/asterisk/{freepbx,asterisk}.log
