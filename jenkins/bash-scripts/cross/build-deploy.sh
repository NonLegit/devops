#!/bin/bash -xe

echo "flutter create .
flutter build web
chown -R 1000:1000 ./build" > script.sh
chmod +x script.sh

docker pull instrumentisto/flutter:latest

# Getting the path of the volume to mount as it exists in the host.
HOST_PATH="/var/bind/jenkins_home/$(realpath --relative-to=/var/jenkins_home/ $PWD)"

set +e

docker run --rm --name=generating-web-files --workdir /usr/src/app -v $HOST_PATH:/usr/src/app instrumentisto/flutter bash -xe script.sh

if [ $? -ne 0 ]; then
	
	# Send email and exit.	
	aws ses send-email --from ysi.rabie@gmail.com --source-arn "arn:aws:ses:us-east-1:965189571202:identity/ysi.rabie@gmail.com" --destination "ToAddresses=ahmedmadbouly186@gmail.com" --region us-east-1 --message "Subject={Data=Error building cross-platform web files},Body={Text={Data=failure, check the logs}}"
	
	exit 0
fi

set -e 

echo "FROM httpd:alpine
COPY ./build/web /usr/local/apache2/htdocs/" > Dockerfile

docker build -t cynic0/reddit-flutter:latest . 
docker rm -f flutter || true
docker run -d --name=flutter --network backend_backend --ip 10.0.1.5 --restart always cynic0/reddit-flutter:latest
