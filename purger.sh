#!/bin/bash

for P in `dpkg -l | grep "^rc" | awk '{ print $2 }'`; do
	dpkg --purge ${P}
done

