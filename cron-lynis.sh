#!/bin/bash

cd /root/Lynis
./lynis -c -Q --auditor "Automatic" --profile ../default.prf --upload
