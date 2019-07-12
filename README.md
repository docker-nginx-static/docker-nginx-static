[![](https://images.microbadger.com/badges/image/flashspys/nginx-static.svg)](https://microbadger.com/images/flashspys/nginx-static "Get your own image badge on microbadger.com") ![](https://img.shields.io/docker/pulls/flashspys/nginx-static.svg)

# Super Lightweight Nginx Image

`docker run -v /path/to/serve:/static -p 8080:80 flashspys/nginx-static`

This command exposes an nginx server on port 8080 which serves the folder `/path/to/serve` from the host.

The image can only be used for static file serving but has with **less than 4 MB** roughly 1/10 the size of the official nginx image. The running container needs **~1 MB RAM**.

### nginx-static via HTTPS

To serve your static files over HTTPS you must use another reverse proxy. We recommend [træfik](https://traefik.io/) as a lightweight reverse proxy with docker integration. Do not even try to get HTTPS working with this image only, as it does not contain the nginx ssl module.

### nginx-static with docker-compose
This is an example entry for a `docker-compose.yaml`
```
version: '3'
services:
  example.org:
    image: flashspys/nginx-static
    container_name: example.org
    ports:
      - 8080:80
    volumes: 
      - /path/to/serve:/static
```


### nginx-static with træfik

To use nginx-static with træfik add an entry to your services in a docker-compose.yaml.

```
services:
  traefik:
    image: traefik
    ...
  example.org:
    image: flashspys/nginx-static
    container_name: example.org
    networks:
      - web
    expose:
      - 80
    labels:
      - traefik.enable=true
      - traefik.backend=example.org
      - traefik.docker.network=web
      - traefik.frontend.rule=Host:example.org
      - traefik.frontend.headers.STSSeconds=315360000
      - traefik.frontend.headers.STSIncludeSubdomains=true
      - traefik.frontend.headers.STSPreload=true
    volumes: 
      - /path/to/serve:/static
```

### nginx-static for multi-stage builds

nginx-static is also suitable for multi-stage builds. This is an example Dockerfile for a static nodejs application:

```
FROM node:alpine
WORKDIR /usr/src/app
COPY . /usr/src/app
RUN npm install && npm run build

FROM flashspys/nginx-static
RUN apk update && apk upgrade
COPY --from=0 /usr/src/app/dist /static
```
