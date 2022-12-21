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
else
        echo "REACT_APP_ENV=production" >> .env
fi

# Clean unncessary files and build the docker image.
rm -rf README* "Unit Testing" devops .git*
echo "Dockerfile" > .dockerignore

docker build -t cynic0/reddit-frontend:latest . 

# Push the docker image.
docker login --username $DOCKER_CREDS_USR --password $DOCKER_CREDS_PSW
docker push cynic0/reddit-frontend:latest

# Deleting credentials file from filesystem.
rm -f /var/jenkins_home/.docker/config.json
