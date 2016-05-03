#!/bin/bash

SERVER=$1

if [ "${SERVER}x" == "x" ]; then
	echo "You can specify a host/domain name on the commandline."
	echo "	e.h. $0 mycustomhost.com"
	echo "Using generic \"server\"...."
	SERVER="server"
fi

openssl genrsa -des3 -out ${SERVER}.key 2048

openssl req -new -key ${SERVER}.key -out ${SERVER}.csr

cp ${SERVER}.key ${SERVER}.key.org
openssl rsa -in ${SERVER}.key.org -out ${SERVER}.key

openssl x509 -req -days 365 -in ${SERVER} -signkey ${SERVER}.key -out ${SERVER}.crt

# copy server.crt /etc/ssl/final_cert_name.pem
# copy server.key /etc/ssl/final_cert_name.key

# enable SSL/TLS config, if necesary

# restart web services
