#!/bin/sh

# This script just creates the directory and base file structure for an ansible role.
# It DOES NOT configure any roles or features itself.  It only creates the platform
# for the ansible role.
#

ROLENAME=$1
ROLEPATH=$2

if [ ! -d ${ROLEPATH}/${ROLENAME} ]; then
	mkdir -p ${ROLEPATH}/${ROLENAME}
fi 

for D in tasks handlers templates files vars defaults meta; do
	mkdir -p ${ROLEPATH}/${ROLENAME}/${D}
done

for D in tasks handlers vars defaults meta; do
	touch ${ROLEPATH}/${ROLENAME}/${D}/main.yml
done
