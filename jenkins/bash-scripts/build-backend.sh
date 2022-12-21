# Set up git credentials.
if [ ! -f "/var/jenkins_home/git-askpass-helper.sh" ]; then
    echo "#!/bin/bash" >> /var/jenkins_home/git-askpass-helper.sh
    echo 'exec echo $GIT_PASSWORD' >> /var/jenkins_home/git-askpass-helper.sh
    chmod +x /var/jenkins_home/git-askpass-helper.sh
fi

export GIT_ASKPASS=/var/jenkins_home/git-askpass-helper.sh

# Getting the backend docker files
mkdir tmp && cd tmp
git clone https://cynico@github.com/NonLegit/devops.git
cp devops/dockerfiles/backend/Dockerfile devops/dockerfiles/backend/docker-compose.yaml ..
cd .. && rm -rf tmp
mv Dockerfile API/
cd API

# Cleaning unnecessary files.
rm -f README* .gitignore
rm -rf config

# Creating the necessary files.
echo "NODE_ENV=production
PORT=8000
DATABASE=mongodb://$DB_CREDS_USR:$DB_CREDS_PSW@mongodb/$DB_NAME?authSource=admin

FRONTDOMAIN=\"https://web.nonlegit.click\"
CROSSDOMAIN=\"https://app.nonlegit.click\"
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=3d
JWT_COOKIE_EXPIRES_IN=3
FIREBASE_SERVER_KEY=$FIREBASE_SERVER_KEY

EMAIL_FROM=$EMAIL_CREDS_USR
NONLEGITEMAIL=$EMAIL_CREDS_USR
NONLEGITPASSWORD=$EMAIL_CREDS_PSW
EMAIL_PORT=$EMAIL_PORT
EMAIL_HOST=$EMAIL_HOST
BACKDOMAIN=\"https://api.nonlegit.click\"

FACEBOOK_APP_ID=$FACEBOOK_APP_USR
FACEBOOK_APP_SECRET=$FACEBOOK_APP_PSW

GOOGLE_APP_ID=$GOOGLE_APP_USR
GOOGLE_APP_SECRET=$GOOGLE_APP_PSW" > .env

# Creating the script-up.sh for the backend container (migrate db files first, then start the server)

echo '#!/bin/sh
npm run up
node server.js' > script-up.sh

sed -i "s/<USER>/$DB_CREDS_USR/g;s/<PASSWORD>/$DB_CREDS_PSW/g" package.json

# Delete/ignore unnecessary files.
rm -rf public

# Build the docker image
docker build -t cynic0/reddit-backend:test .

# Run unit test
set +e

docker run --rm cynic0/reddit-backend:test npm test > unit-test.log 2>&1
if [ $? -ne 0 ]; then

    # Send email to one of the backend team.

    AUTHOR=`git log -1 | grep Author | cut -d ' ' -f2 - | awk '{ print tolower($0) }'`

    case $AUTHOR in
        kiro*)
            TO_EMAIL="kirollossamyhakim@gmail.com"
            ;;
        ahmed*)
            TO_EMAIL="ahmedsabry232345@gmail.com"
            ;;
        doaa*)
            TO_EMAIL="doaaelsherif11@gmail.com"
            ;;
        khaled*)
            TO_EMAIL="kha.hesham@gmail.com"
            ;;
        *)
            TO_EMAIL="ysi.rabie@gmail.com"
            ;;
    esac

    aws s3 cp unit-test.log s3://nonlegit-logs
    aws ses send-email --from "$SOURCE_EMAIL" --source-arn "arn:aws:ses:us-east-1:965189571202:identity/ysi.rabie@gmail.com" --destination "ToAddresses=$TO_EMAIL" --region us-east-1 --message "Subject={Data=unit test failed},Body={Text={Data=check out this for the logs: https://nonlegit-logs.s3.amazonaws.com/unit-test.log}}" 

    # Remove the image.
    docker image rm cynic0/reddit-backend:test
    docker image prune -f
    exit 1
fi
set -e


# Building the production version (ignoring dockerfile, test files, etc)
rm -rf unit-test.log test mochawesome-report
echo "Dockerfile" > .dockerignore

docker build -t cynic0/reddit-backend:latest .
docker image rm cynic0/reddit-backend:test

docker image prune -f

# Push the docker image.
docker login --username $DOCKER_CREDS_USR --password $DOCKER_CREDS_PSW
docker push cynic0/reddit-backend:latest

# Deleting credentials file from filesystem.
rm -f /var/jenkins_home/.docker/config.json

# Modify the docker compose file.
cd ..
sed -i "s/DB_USER/$DB_CREDS_USR/g;s/DB_PASSWORD/$DB_CREDS_PSW/g" docker-compose.yaml
if [ ! -d /var/jenkins_home/docker-compose ]; then
    mkdir -p /var/jenkins_home/docker-compose/backend
    mkdir /var/jenkins_home/docker-compose/frontend
fi

# Moving the cloned docker-compose file to the destination for the stage of deploying.
mv docker-compose.yaml /var/jenkins_home/docker-compose/backend
