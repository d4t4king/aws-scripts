#!/bin/bash

#self 
git pull https://github.com/d4t4king/aws-scripts master
#aws2
ssh -i /home/ubuntu/AWS-SWE-Charlie.pem ubuntu@aws2.dataking.us 'cd /home/ubuntu/scripts/; git pull https://github.com/d4t4king/aws-scripts master'

#www
ssh -i /home/ubuntu/AWS-EBS-Charlie.pem ubuntu@www.dataking.technology 'cd /home/ubuntu/scripts/; git pull https://github.com/d4t4king/aws-scripts master'
