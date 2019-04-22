# Magrab

Margrethe's image grabbing stop motion play house.

Built with docker, a node.js backend and an elm frontend.

Publish docker image with
```
docker login
docker build . -t magrab:latest
docker tag magrab larsim/magrab:latest
docker push larsim/magrab:latest
```

Test while developing with
```
docker build . -t magrab:latest
docker run -p 127.0.0.1:3000:3000 -e IMAGE_PATH=/magrab/images -e DB_FILE_PATH=/magrab/magrab-projects.db -e VIDEO_PATH=/magrab/gifs -v $(PWD):/magrab -it --entrypoint /bin/sh magrab:latest
```

Adapt the docker-compose.yml to match your set up (ports/volumes)

Adapt to your ip camera url/auth scheme as needed.

