#!/bin/bash

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

# check for custom cron schedule
if [[ -n "$CRON_SCHEDULE" ]]; then
  sed -i 's|\* \* \* \* \*|'"$CRON_SCHEDULE"'|g' /etc/cron.d/save-attachments
  echo "Installed custom cron: $CRON_SCHEDULE"
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
