#!/bin/bash

################################################
### 12/5/2025
### Script to pull latest changes from GitHub repo to all AWS instances
### This script is now deprecated as we have moved to using Ansible for configuration management.
### However, it is kept here for reference.
################################################

#self 
git pull https://github.com/d4t4king/aws-scripts master

#aws2
#ssh -i /home/ubuntu/AWS-SWE-Charlie.pem ubuntu@aws2.dataking.us 'cd /home/ubuntu/scripts/; git pull https://github.com/d4t4king/aws-scripts master'

#dataking.technology
ssh -i AWS-EBS-Charlie.pem ubuntu@dataking.technology 'cd /root//scripts; git pull https://github.com/d4t4king/aws-scripts master'

#diegominpin.com
ssh -i AWS-EBS-Charlie.pem ubuntu@diegominpin.com 'cd /root/scripts; git pull https://github.com/d4t4king/aws-scripts master'
