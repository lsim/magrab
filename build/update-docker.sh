#!/bin/bash

set -e

npm run build-prod

docker login
docker build . -t magrab:latest
docker tag magrab larsim/magrab:latest
docker push larsim/magrab:latest
