#!/bin/bash -u

# if you want to experiment various config, you can describe below.

function check_root_user {
	if [ $(whoami) != "root" ]; then
        echo "permission denied"
        exit
	fi	
}

check_root_user

./main.sh "normal" default.conf

exit
