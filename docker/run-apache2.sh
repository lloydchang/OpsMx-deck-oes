# Set any missing env variables used to configure deck

_DECK_HOST=$DECK_HOST
_DECK_PORT=$DECK_PORT
_API_HOST=$API_HOST
_DECK_CERT_PATH=$DECK_CERT
_DECK_KEY_PATH=$DECK_KEY
_PASSPHRASE=$PASSPHRASE

if [ -z "$_DECK_HOST" ];
then
    _DECK_HOST=0.0.0.0
fi

if [ -z "$_DECK_PORT" ];
then
    _DECK_PORT=9000
fi

if [ -z "$_API_HOST" ];
then
    _API_HOST=http://localhost:8084
fi

if [ -z "$_DECK_CERT_PATH" ];
then
	# SSL not enabled
	cp docker/spinnaker.conf.gen spinnaker.conf
else
	a2enmod ssl
	cp docker/spinnaker.conf.ssl spinnaker.conf
	sed -ie 's|{%DECK_CERT_PATH%}|'$_DECK_CERT_PATH'|g' spinnaker.conf
	sed -ie 's|{%DECK_KEY_PATH%}|'$_DECK_KEY_PATH'|g' spinnaker.conf
fi

# Generate spinnaker.conf site & enable it

sed -ie 's|{%DECK_HOST%}|'$_DECK_HOST'|g' spinnaker.conf
sed -ie 's|{%DECK_PORT%}|'$_DECK_PORT'|g' spinnaker.conf
sed -ie 's|{%API_HOST%}|'$_API_HOST'|g' spinnaker.conf

mkdir -p /etc/apache2/sites-available
mv spinnaker.conf  /etc/apache2/sites-available

a2ensite spinnaker

# Disable default site

a2dissite 000-default

# Update ports.conf to reflect desired deck host

cp docker/ports.conf.gen ports.conf

sed -ie "s|{%DECK_HOST%}|$_DECK_HOST|g" ports.conf
sed -ie "s|{%DECK_PORT%}|$_DECK_PORT|g" ports.conf 
mv ports.conf /etc/apache2/ports.conf

# Create a passphrase file to inject the SSL passphrase into apache's startup

cp docker/passphrase.gen passphrase

sed -ie "s|{%PASSPHRASE%}|$_PASSPHRASE|g" passphrase

# Clear password from env vars 

_PASSPHRASE=""
PASSPHRASE=""

chmod +x passphrase
mv passphrase /etc/apache2/passphrase

if [ -e /opt/spinnaker/config/settings.js ];
then 
	cp /opt/spinnaker/config/settings.js /opt/deck/html/settings.js
fi

if [ -e /opt/spinnaker/config/settings-local.js ];
then 
	cp /opt/spinnaker/config/settings-local.js /opt/deck/html/settings-local.js
	# Apache user must be the owner of settings-local.js file, not spinnaker user, so that it can display custom profiles features on Deck UI
	chown www-data /opt/deck/html/settings-local.js
fi

if [ -e /opt/spinnaker/config/plugin-manifest.json ];
then 
	cp /opt/spinnaker/config/plugin-manifest.json /opt/deck/html/plugin-manifest.json
fi

apache2ctl -D FOREGROUND 
