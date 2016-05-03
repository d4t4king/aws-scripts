#!/bin/bash

SERVER=$1

if [ "${SERVER}x" == "x" ]; then
	echo "You can specify a host/domain name on the commandline."
	echo "	e.g. $0 mycustomhost.com"
	echo "Using generic \"server\"...."
	SERVER="server"
fi

pushd /tmp/

openssl genrsa -aes256 -out ${SERVER}.key 2048

openssl req -new -key ${SERVER}.key -out ${SERVER}.csr

cp ${SERVER}.key ${SERVER}.key.org
openssl rsa -in ${SERVER}.key.org -out ${SERVER}.key

openssl x509 -req -days 365 -in ${SERVER}.csr -signkey ${SERVER}.key -out ${SERVER}.crt

# copy server.crt /etc/ssl/final_cert_name.pem
# copy server.key /etc/ssl/final_cert_name.key
mv ${SERVER}.crt /etc/ssl/
mv ${SERVER}.key /etc/ssl/

# enable SSL/TLS config, if necesary

# restart web services

popd

