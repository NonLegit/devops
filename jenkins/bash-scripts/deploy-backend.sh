#!/bin/bash

DROPDB=true
if [ -z $(git log -1 | grep "dropdb" ) ]; then
    DROPDB=false
fi

AUTHOR=`git log -1 | grep Author | cut -d ' ' -f2 - | awk '{ print tolower($0) }'`

cd /var/jenkins_home/docker-compose/backend
docker compose down || true

# Dropping the db.
if [ "$DROPDB" = true ]; then
	docker run --rm --name=dropdb-workaround -v /home/userns-user/mongodb:/mongodb/ bash sh -c 'rm -rf /mongodb/*'
fi

docker compose up -d

# Creating the users if the db is dopped.
if [ "$DROPDB" = true ]; then
    docker exec backend-mongodb-1 mongosh -u $DB_CREDS_USR -p $DB_CREDS_PSW --eval "db = db.getSiblingDB(\"redditDB\"); db.createUser( { user: \"$NONLEGIT_USR\", pwd: \"$NONLEGIT_PSW\", roles: [ { role: \"read\", db: \"redditDB\" } ] }); db.createUser( { user: \"$BACKEND_USR\", pwd: \"$BACKEND_PSW\", roles: [ { role: \"readWrite\", db: \"redditDB\" } ] })"
fi

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

aws ses send-email --from $SOURCE_EMAIL --source-arn "arn:aws:ses:us-east-1:965189571202:identity/ysi.rabie@gmail.com" --destination "ToAddresses=$TO_EMAIL" --region us-east-1 --message "Subject={Data=Deployment Successful},Body={Text={Data=success}}"
