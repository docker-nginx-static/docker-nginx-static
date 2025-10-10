[![](https://images.microbadger.com/badges/image/flashspys/nginx-static.svg)](https://microbadger.com/images/flashspys/nginx-static "Get your own image badge on microbadger.com") ![](https://img.shields.io/docker/pulls/flashspys/nginx-static.svg)

# Super Lightweight Nginx Image

`docker run -v /absolute/path/to/serve:/static -p 8080:80 flashspys/nginx-static`

This command exposes an nginx server on port 8080 which serves the folder `/absolute/path/to/serve` from the host.

The image can only be used for static file serving but has with **less than 4 MB** roughly 1/10 the size of the official nginx image. The running container needs **~1 MB RAM**.

### nginx-static via HTTPS

To serve your static files over HTTPS you must use another reverse proxy. We recommend [træfik](https://traefik.io/) as a lightweight reverse proxy with docker integration. Do not even try to get HTTPS working with this image only, as it does not contain the nginx ssl module.

## nginx-static with docker-compose
This is an example entry for a `docker-compose.yaml`
```yaml
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


## nginx-static with træfik 2.x

To use nginx-static with træfik 2.x add an entry to your services in a docker-compose.yaml. To set up traefik look at this [simple example](https://docs.traefik.io/user-guides/docker-compose/basic-example/). 

In the following example, replace everything contained in \<angle brackets\> and the domain with your values.

```yaml
services:
  traefik:
    image: traefik:2.4 # check if there is a newer version
  # Your traefik config.
    ...
  example.org:
    image: flashspys/nginx-static
    container_name: example.org
    expose:
      - 80
    deploy:
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.<router>.rule=Host(`example.org`)"
        - "traefik.http.routers.<router>.entrypoints=<entrypoint>"
# If you want to enable SSL, uncomment the following line.
#      - "traefik.http.routers.<router>.tls.certresolver=<certresolver>"
    volumes: 
      - /host/path/to/serve:/static
```

If traefik and the nginx-static are in distinct docker-compose.yml files, please make sure that they are in the [same network](https://doc.traefik.io/traefik/routing/providers/docker/#traefikdockernetwork).

For a traefik 1.7 example look [at an old version of the readme](https://github.com/flashspys/docker-nginx-static/blob/bb46250b032d187cab6029a84335099cc9b4cb0e/README.md)

## nginx-static for multi-stage builds

nginx-static is also suitable for multi-stage builds. This is an example Dockerfile for a static node.js application:

```dockerfile
FROM node:alpine
WORKDIR /usr/src/app
COPY . /usr/src/app
RUN npm install && npm run build

FROM flashspys/nginx-static
RUN apk update && apk upgrade
COPY --from=0 /usr/src/app/dist /static
```

### Custom nginx config

In the case you already have your own Dockerfile you can easily adjust the nginx config by adding the following command in your Dockerfile. In case you don't want to create an own Dockerfile you can also add the configuration via volumes, e.g. appending `-v /absolute/path/to/custom.conf:/etc/nginx/conf.d/default.conf` in the command line or adding the volume in the docker-compose.yaml respectively. This can be used for advanced rewriting rules or adding specific headers and handlers. See the default config [here](nginx.vh.default.conf).

```dockerfile
…
FROM flashspys/nginx-static
RUN rm -rf /etc/nginx/conf.d/default.conf
COPY your-custom-nginx.conf /etc/nginx/conf.d/default.conf
```
