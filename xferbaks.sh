#!/bin/bash

# we should get the website and the year at a minimum
year_rgx='^20[0-9][0-9]$'
num_rgx='^[0-9]+$'
case $# in 
	2)
		echo "Got 2 arguments: $1 and $2"
		if ! [[ $2 =~ $year_rgx ]]; then
			echo "Expected args: <site> <year> [month]"
		else
			# pull the baks for the year
			# assume it's a whole year
			# start with single didit months, 
			# but they must be 0 padded
			for M in $(seq 1 9); do
				# same for days: start with single
				# digits but must be 0 padded
				for D in $(seq 1 9); do
					FILE=$(aws s3 ls s3://dk-website-backups/$1/${1}-${2}-0${M}-0${D}.tar.xz)
					if [ "$FILE" == "" ]; then
						echo "File not exist (${1}-${2}-0${M}-0${D}.tar.xz)"
					else
						aws s3 cp s3://dk-website-backups/$1/${1}-${2}-0${M}-0${D}.tar.xz /tmp/
						scp -P 3333 /tmp/${1}-${2}-0${M}-0${D}.tar.xz dataking.us:/opt/backups/$1/
						if [ $? == 0 ]; then
							rm -vf /tmp/${1}-${2}-0${M}-0${D}.tar.xz
							aws s3 rm s3://dk-website-backups/$1/${1}-${2}-0${M}-0${D}.tar.xz
						else
							echo "There was a problem with the copy.  Aborting."
							exit 1
						fi
					fi
				done
				for D in $(seq 10 31); do
					FILE=$(aws s3 ls s3://dk-website-backups/$1/${1}-${2}-0${M}-${D}.tar.xz)
					if [ "$FILE" == "" ]; then
						echo "File not exist (${1}-${2}-0${M}-${D}.tar.xz)"
					else
						aws s3 cp s3://dk-website-backups/$1/${1}-${2}-0${M}-${D}.tar.xz /tmp/
						scp -P 3333 /tmp/${1}-${2}-0${M}-${D}.tar.xz dataking.us:/opt/backups/$1/
						if [ $? == 0 ]; then
							rm -vf /tmp/${1}-${2}-0${M}-${D}.tar.xz
							aws s3 rm s3://dk-website-backups/$1/${1}-${2}-0${M}-${D}.tar.xz
						else
							echo "There was a problem with the copy.  Aborting."
							exit 1
						fi
					fi
				done
			done
			for M in 10 11 12; do
				for D in $(seq 1 9); do
					FILE=$(aws s3 ls s3://dk-website-backups/$1/${1}-${2}-${M}-0${D}.tar.xz)
					if [ "$FILE" == "" ]; then
						echo "File not exist (${1}-${2}-${M}-0${D}.tar.xz)"
					else
						aws s3 cp s3://dk-website-backups/$1/${1}-${2}-${M}-0${D}.tar.xz /tmp/
						scp -P 3333 /tmp/${1}-${2}-${M}-0${D}.tar.xz dataking.us:/opt/backups/$1/
						if [ $? == 0 ]; then
							rm -vf /tmp/${1}-${2}-${M}-0${D}.tar.xz
							aws s3 rm s3://dk-website-backups/$1/${1}-${2}-${M}-0${D}.tar.xz
						else
							echo "There was a problem with the copy.  Aborting."
							exit 1
						fi
					fi
				done
				for D in $(seq 10 31); do
					FILE=$(aws s3 ls s3://dk-website-backups/$1/${1}-${2}-${M}-${D}.tar.xz)
					if [ "$FILE" == "" ]; then
						echo "File not exist (${1}-${2}-${M}-${D}.tar.xz)"
					else
						aws s3 cp s3://dk-website-backups/$1/${1}-${2}-${M}-${D}.tar.xz /tmp/
						scp -P 3333 /tmp/${1}-${2}-${M}-${D}.tar.xz dataking.us:/opt/backups/$1/
						if [ $? == 0 ]; then
							rm -vf /tmp/${1}-${2}-${M}-${D}.tar.xz
							aws s3 rm s3://dk-website-backups/$1/${1}-${2}-${M}-${D}.tar.xz
						else
							echo "There was a problem with the copy.  Aborting."
							exit 1
						fi
					fi
				done
			done
		fi
		;;
	3)
		echo "Got 3 arguments: $1 , $2 and $3"
		if ! [[ $2 =~ $year_rgx ]] && [[ $3 =~ $num_rgx ]]; then
			echo "Didn't get valid options: YEAR: $2 MONTH: $3"
			exit 2
		else
			# start with the 0 padded numbers
			for D in $(seq 1 9); do
				FILE=$(aws s3 ls s3://dk-website-backups/$1/${1}-${2}-${3}-0${D}.tar.xz)
				if [ "$FILE" == "" ]; then
					echo "File not exist (${1}-${2}-${3}-0${D}.tar.xz)"
				else
					aws s3 cp s3://dk-website-backup/${1}-${2}-${3}-0${D}.tar.xz /tmp/
					scp -P 3333 /tmp/${1}-${2}-${3}-0${D}.tar.xz dataking.us:/opt/backups/$1/
					if [ $? == 0 ]; then
						rm -vf /tmp/${1}-${2}-${3}-0${D}.tar.xz
						aws s3 rm s3://dk-website-backups/$1/${1}-${2}-${3}-0${D}.tar.xz
					else
						echo "There was a problem with the copy.  Aborting."
						exit 1
					fi
				fi
			done
			for D in $(seq 10 31); do
				FILE=$(aws s3 ls s3://dk-website-backups/$1/${1}-${2}-${3}-${D}.tar.xz)
				if [ "$FILE" == "" ]; then
					echo "File not exist (${1}-${2}-${3}-${D}.tar.xz)"
				else
					aws s3 cp s3://dk-website-backup/${1}-${2}-${3}-${D}.tar.xz /tmp/
					scp -P 3333 /tmp/${1}-${2}-${3}-${D}.tar.xz dataking.us:/opt/backups/$1/
					if [ $? == 0 ]; then
						rm -vf /tmp/${1}-${2}-${3}-${D}.tar.xz
						aws s3 rm s3://dk-website-backups/$1/${1}-${2}-${3}-${D}.tar.xz
					else
						echo "There was a problem with the copy.  Aborting."
						exit 1
					fi
				fi
			done
		fi
		;;
	*)	
		echo "Unexpected number of arguments! ($#)"
		;;
esac

