#!/bin/bash

# Set up git credentials.
if [ ! -f "/var/jenkins_home/git-askpass-helper.sh" ]; then
    echo "#!/bin/bash" >> /var/jenkins_home/git-askpass-helper.sh
    echo 'exec echo $GIT_PASSWORD' >> /var/jenkins_home/git-askpass-helper.sh
    chmod +x /var/jenkins_home/git-askpass-helper.sh
fi

export GIT_ASKPASS=/var/jenkins_home/git-askpass-helper.sh

# Getting the frontend dockerfiles
mkdir temp; cd temp
git clone https://cynico@github.com/NonLegit/devops.git
cp devops/dockerfiles/frontend/Dockerfile ..
cd .. ; rm -rf temp

DEVELOPMENT=true
if [ -z "$(git log -1 | grep "development" )" ]; then
    DEVELOPMENT=false
fi

# Creating the .env file.
echo "HTTP=false
PORT=443
HOST=0.0.0.0
REACT_APP_GOOGLECLIENTID=\"$GOOGLE_APP_ID\"
REACT_APP_FACEBOOKCLIENTID=\"$FACEBOOK_APP_ID\"
REACT_APP_SITEKEY=\"$REACT_APP_SITEKEY\"
REACT_APP_PROXY_DEVELOPMENT=\"http://localhost:8000\"
REACT_APP_PROXY_PRODUCTION=\"https://api.nonlegit.click/api/v1\"" > .env

if [ "$DEVELOPMENT" = true ]; then
        echo "REACT_APP_ENV=development" >> .env
        sed -i 's/--omit=dev//g' Dockerfile
else
        echo "REACT_APP_ENV=production" >> .env
fi

# Clean unncessary files and build the docker image.
rm -rf README* "Unit Testing" devops .git*
echo "Dockerfile" > .dockerignore

# Getting latest server-json from the development branch.
rm -rf data
git clone -b main https://github.com/NonLegit/Reddit-Front.git
mv Reddit-Front/data . && rm -rf Reddit-Front

# Run unit testing..
docker build -t cynic0/reddit-frontend:test .
set +e

docker run --rm cynic0/reddit-frontend:test npm test > unit-test-frontend.log 2>&1
if [ $? -ne 0 ]; then

    # Send email to the leader of the frontend team.
    TO_EMAIL=${TO_EMAIL:-ysi.rabie@gmail.com}

    aws s3 cp unit-test-frontend.log s3://nonlegit-logs
    aws ses send-email --from "ysi.rabie@gmail.com" --source-arn "arn:aws:ses:us-east-1:965189571202:identity/ysi.rabie@gmail.com" --destination "ToAddresses=$TO_EMAIL" --region us-east-1 --message "Subject={Data=unit test failed},Body={Text={Data=check out this for the logs: https://nonlegit-logs.s3.amazonaws.com/unit-test-frontend.log}}" 

    # Remove the image.
    docker image rm cynic0/reddit-frontend:test
    docker image prune -f
    exit 1
fi

set -e

rm -f unit-test-frontend.log
docker build -t cynic0/reddit-frontend:latest . 
docker image rm cynic0/reddit-frontend:test

# Push the docker image.
docker login --username $DOCKER_CREDS_USR --password $DOCKER_CREDS_PSW
docker push cynic0/reddit-frontend:latest

# Deleting credentials file from filesystem.
rm -f /var/jenkins_home/.docker/config.json
