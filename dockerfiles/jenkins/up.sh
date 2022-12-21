#!/bin/sh

sed -i "s/REPLACE_ME/`getent group docker | cut -d: -f3`/g" docker-compose.yaml
docker compose up --build -d
