#!/bin/bash


if [ -z "${USER_GID}" ]; then
  USER_GID="`id -g ${USER}`"
fi

if [ -z "${USER_UID}" ]; then
  USER_UID="`id -u ${USER}`"
fi

## Change GID for USER?
if [ -n "${USER_GID}" ] && [ "${USER_GID}" != "`id -g ${USER}`" ]; then
    sed -i -e "s/^${USER}:\([^:]*\):[0-9]*/${USER}:\1:${USER_GID}/" /etc/group
    sed -i -e "s/^${USER}:\([^:]*\):\([0-9]*\):[0-9]*/${USER}:\1:\2:${USER_GID}/" /etc/passwd
fi

## Change UID for USER?
if [ -n "${USER_UID}" ] && [ "${USER_UID}" != "`id -u ${USER}`" ]; then
    sed -i -e "s/^${USER}:\([^:]*\):[0-9]*:\([0-9]*\)/${USER}:\1:${USER_UID}:\2/" /etc/passwd
fi

# verify maildir
if [ -d /var/mail/working ]; then
    echo "/var/mail/working exists"
    chown -R root /var/mail/working
else
    maildirmake /var/mail/working
    mkdir /var/mail/working/landing
    mkdir /var/mail/working/extracted
    echo "to /var/mail/working" > /root/.mailfilter
    touch /var/mail/save-attachments.log
fi

# check for user config fetchmailrc
if [ -f /config/.fetchmailrc ]; then
    cp /config/.fetchmailrc /root/.fetchmailrc
    # ensure maildrop is the MDA
    if grep --quiet '^mda "/usr/bin/maildrop"' /root/.fetchmailrc; then
        echo "MDA correctly configured"
    else
        if grep --quiet '^mda' /root/.fetchmailrc; then
            sed -i 's/mda.*/mda "\/usr\/bin\/maildrop"/' /root/.fetchmailrc
        else
            echo 'mda "/usr/bin/maildrop"' >> /root/.fetchmailrc
        fi
    fi
    chmod 0700 /root/.fetchmailrc
    echo "Installed .fetchmailrc"
fi

# update CA certificates if necessary from /config/*.crt
if stat --printf='' /config/*.crt 2>/dev/null
then
    cp -v /config/*.crt /usr/local/share/ca-certificates/
    update-ca-certificates
fi

echo "$1"
if [ "$1" = 'cron' ] || [ "$1" = '/opt/save-attachments.sh' ]; then
    if [ ! -f /root/.fetchmailrc ]; then
        echo "Cannot start container without .fetchmailrc"
        exit 1
    fi
fi

if [ "$1" = 'cron' ]; then
    /usr/sbin/cron && tail -f /var/mail/save-attachments.log
    exit $?
fi

exec $@
