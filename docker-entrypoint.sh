#!/bin/sh

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

ME=$(basename "$0")
DEFAULT_CONF_FILE="/etc/nginx/conf.d/default.conf"
DEFAULT_CONF_SUM="/usr/share/nginx-static/default.conf.sha256"

# nginx fails to start when binding an IPv6 socket on a kernel without IPv6 support.
# This step is best effort: it must never stop the container from starting.
enable_ipv6_listen() {
    if [ ! -f "/proc/net/if_inet6" ]; then
        entrypoint_log "$ME: info: ipv6 not available"
        return 0
    fi

    if [ ! -f "$DEFAULT_CONF_FILE" ]; then
        entrypoint_log "$ME: info: $DEFAULT_CONF_FILE is not a file or does not exist"
        return 0
    fi

    if grep -q "listen       \[::\]:80;" "$DEFAULT_CONF_FILE"; then
        entrypoint_log "$ME: info: IPv6 listen already enabled"
        return 0
    fi

    if [ ! -f "$DEFAULT_CONF_SUM" ]; then
        entrypoint_log "$ME: info: $DEFAULT_CONF_SUM not found, assuming a custom config"
        return 0
    fi

    # only touch the config we shipped; anything else belongs to the user
    if [ "$(sha256sum < "$DEFAULT_CONF_FILE")" != "$(cat "$DEFAULT_CONF_SUM")" ]; then
        entrypoint_log "$ME: info: $DEFAULT_CONF_FILE differs from the shipped default config"
        return 0
    fi

    # sed -i writes a temp file next to the config, so the directory must be writable too.
    # [ -w ] is true for root even on a read-only file system, hence the sed fallback below.
    if [ ! -w "$DEFAULT_CONF_FILE" ] || [ ! -w "$(dirname "$DEFAULT_CONF_FILE")" ]; then
        entrypoint_log "$ME: info: can not modify $DEFAULT_CONF_FILE (read-only file system?)"
        return 0
    fi

    if ! sed -i 's,listen       80;,listen       80;\n    listen       [::]:80;,' "$DEFAULT_CONF_FILE" 2>/dev/null; then
        entrypoint_log "$ME: info: can not modify $DEFAULT_CONF_FILE (read-only file system?)"
        return 0
    fi

    entrypoint_log "$ME: info: Enabled listen on IPv6 in $DEFAULT_CONF_FILE"
}

enable_ipv6_listen

exec "$@"
