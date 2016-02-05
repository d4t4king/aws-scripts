#!/bin/bash

openssl genrsa -des3 -out server.key 2048

openssl req -new -key server.key -out server.csr

cp server.key server.key.org
openssl rsa -in server.key.org -out server.key

openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

# copy server.crt /etc/ssl/final_cert_name.pem
# copy server.key /etc/ssl/fins_cert_name.key

# enable SSL/TLS config, if necesary

# restart web services
