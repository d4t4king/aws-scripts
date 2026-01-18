#!/bin/bash

echo "Updating self..."
sudo apt-get update
sudo apt-get upgrade
echo "aws2..."
ssh -i /home/ubuntu/AWS-SWE-Charlie.pem ubuntu@aws2.dataking.us 'sudo apt-get update'
ssh -i /home/ubuntu/AWS-SWE-Charlie.pem ubuntu@aws2.dataking.us 'sudo apt-get upgrade'
echo "And finally www..."
ssh -i /home/ubuntu/AWS-EBS-Charlie.pem ubuntu@www.dataking.technology 'sudo apt-get update'
ssh -i /home/ubuntu/AWS-EBS-Charlie.pem ubuntu@www.dataking.technology 'sudo apt-get upgrade'
