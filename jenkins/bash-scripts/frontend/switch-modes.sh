#!/bin/bash

CURRENT=deployment
FIRST_TIME=true

function switch_modes() {
        if [ $CURRENT = deployment ]; then
                CURRENT=development
                if [ ! -z \"`npm list -g forever | grep -o empty`\" ]; then 
                        npm install -g forever
                fi
                kill -SIGKILL -$(ps ao command,pgid | grep 'npm start' | grep -v grep | awk '{ print $NF}')
                sed -i 's/REACT_APP_ENV=production/REACT_APP_ENV=development/g' .env
		
		if [ $FIRST_TIME = true ]; then
			npm install --force
			FIRST_TIME = false		
		fi

                forever /usr/src/app/node_modules/.bin/json-server --watch /usr/src/app/data/index.js --port 8000 --routes /usr/src/app/data/routes.json &
        	
	else
                CURRENT=deployment
                kill -SIGKILL -$(ps ao command,pgid | grep 'forever' | grep -v grep | awk '{ print $NF }')
                sed -i 's/REACT_APP_ENV=development/REACT_APP_ENV=production/g' .env
        fi
}

trap switch_modes SIGINT

while true; do
        npm start
done
