#!/bin/bash

#self 
git pull https://github.com/d4t4king/aws-scripts master

#aws2
#ssh -i /home/ubuntu/AWS-SWE-Charlie.pem ubuntu@aws2.dataking.us 'cd /home/ubuntu/scripts/; git pull https://github.com/d4t4king/aws-scripts master'

#dataking.technology
ssh -i AWS-EBS-Charlie.pem ubuntu@dataking.technology 'cd /root//scripts; git pull https://github.com/d4t4king/aws-scripts master'

#diegominpin.com
ssh -i AWS-EBS-Charlie.pem ubuntu@diegominpin.com 'cd /root/scripts; git pull https://github.com/d4t4king/aws-scripts master'
