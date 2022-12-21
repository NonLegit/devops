#!/bin/sh

docker rm -f frontend
docker run --name=frontend --network backend_backend --ip 10.0.1.4 --restart always -d cynic0/reddit-frontend:latest
