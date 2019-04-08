[![](https://images.microbadger.com/badges/image/flashspys/nginx-static.svg)](https://microbadger.com/images/flashspys/nginx-static "Get your own image badge on microbadger.com") ![](https://img.shields.io/docker/pulls/flashspys/nginx-static.svg)

# Super Lightweight Nginx Image

`docker run -v /srv/web:/static -p 8080:80 flashspys/nginx-static`

This command exposes an nginx server on port 8080 which serves the folder `/srv/web` from the host.

The image is roughly half the size of the official nginx image and can only be used for static file serving.

### nginx-static via HTTPS

To serve your static files over HTTPS you must use another reverse proxy. We recommend [træfik](https://traefik.io/) as a lightweight reverse proxy with docker integration. Do not even try to get HTTPS working with this image only, as it does not contain the nginx ssl module.

### nginx-static
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
      - /srv/web:/static
```


### nginx-static with træfik

To use nginx-static with træfik add an entry to your services in a docker-compose.yaml.

```
  example.org:
    image: flashspys/nginx-static
    container_name: example.org
    networks:
      - web
    expose:
      - 80
    labels:
      - traefik.backend=example.org
      - traefik.docker.network=web
      - traefik.frontend.rule=Host:example.org
      - traefik.frontend.headers.STSSeconds=315360000
      - traefik.frontend.headers.STSIncludeSubdomains=true
      - traefik.frontend.headers.STSPreload=true
    volumes: 
      - /srv/web:/static
```

### nginx-static for multi-stage builds

nginx-static is also suitable for multi-stage builds. This is an example Dockerfile:

```
FROM node:alpine
WORKDIR /usr/src/app
COPY . /usr/src/app
RUN npm install && npm run build

FROM flashspys/nginx-static
RUN apk update && apk upgrade
COPY --from=0 /usr/src/app/dist /static
```
