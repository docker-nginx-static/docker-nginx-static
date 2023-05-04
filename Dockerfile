FROM alpine:3.17

LABEL maintainer="Felix Wehnert <felix@wehnert.me>,Maximilian Hippler <hello@maximilian.dev>"

# renovate: datasource=docker depName=library/nginx versioning=semver
ENV NGINX_VERSION 1.23.4

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
WORKDIR /usr/src

RUN GPG_KEYS="B0F4253373F8F6F510D42178520A9993A1C052F8 \
	41DB92713D3BF4BFF3EE91069C5E7FA2F54977D4 \
	7338973069ED3F443F4D37DFA64FD5B17ADB39A8 \
	13C82A63B603576156E30A4EA0EA981B66B0D967 \
	573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62" \
	&& CONFIG="\
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-threads \
	--with-file-aio \
	" \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
	gcc \
	libc-dev \
	make \
	pcre-dev \
	zlib-dev \
	linux-headers \
	curl \
	gnupg \
	gd-dev \
	&& curl -fSL "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz" -o nginx.tar.gz \
	&& curl -fSL "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc"  -o nginx.tar.gz.asc \
	# Mitigate Shellcheck 2086, we want to split words
	&& fetch_gpg_keys() { \
	set -- "$@" "--recv-keys"; \
	for key in $GPG_KEYS; do set -- "$@" "$key"; done; \
	gpg "$@"; \
	} \
	&& GNUPGHOME="$(mktemp -d)" \
	&& export GNUPGHOME \
	&& found=''; \
	for server in \
	hkp://keyserver.ubuntu.com:80 \
	pgp.mit.edu \
	; do \
	echo "Fetching GPG keys $GPG_KEYS from $server"; \
	fetch_gpg_keys --keyserver "$server" --keyserver-options timeout=10 && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG keys $GPG_KEYS" && exit 1; \
	gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
	&& tar -zx --strip-components=1 -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	# Mitigate Shellcheck 2086, we want to split words
	&& make_config() { \
	for config_element in $CONFIG; do set -- "$@" "$config_element"; done; \
	set -- "$@" "--with-debug"; \
	set -o xtrace; \
	./configure "$@"; \
	set +o xtrace; \
	} \
	&& make_config \
	&& make -j "$(getconf _NPROCESSORS_ONLN)" \
	&& mv objs/nginx objs/nginx-debug \
	&& make_config \
	&& make -j "$(getconf _NPROCESSORS_ONLN)" \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& rm -rf /usr/src \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/\
	&& runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
	| tr ',' '\n' \
	| sort -u \
	| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	# Mitigate Shellcheck 2086, we want to split words
	&& install_deps() { \
	for dep in $runDeps; do set -- "$dep" "$@"; done; \
	apk add --no-cache --virtual .nginx-rundeps "$@"; \
	} \
	&& install_deps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# Bring in tzdata so users could set the timezones through the environment
	# variables
	&& apk add --no-cache tzdata \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& mkdir /static

COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
