#!/bin/sh

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

ME=$(basename "$0")
DEFAULT_CONF_FILE="/etc/nginx/conf.d/default.conf"
DEFAULT_CONF_SHIPPED="$DEFAULT_CONF_FILE.dist"

# nginx fails to start when binding an IPv6 socket on a kernel without IPv6 support
enable_ipv6_listen() {
    if [ ! -f "/proc/net/if_inet6" ]; then
        entrypoint_log "$ME: info: ipv6 not available"
        return 0
    fi

    if [ ! -f "$DEFAULT_CONF_FILE" ]; then
        entrypoint_log "$ME: info: $DEFAULT_CONF_FILE is not a file or does not exist"
        return 0
    fi

    touch "$DEFAULT_CONF_FILE" 2>/dev/null || { entrypoint_log "$ME: info: can not modify $DEFAULT_CONF_FILE (read-only file system?)"; return 0; }

    grep -q "listen       \[::\]:80;" "$DEFAULT_CONF_FILE" && { entrypoint_log "$ME: info: IPv6 listen already enabled"; return 0; }

    if [ ! -f "$DEFAULT_CONF_SHIPPED" ]; then
        entrypoint_log "$ME: info: $DEFAULT_CONF_SHIPPED not found, assuming a custom config"
        return 0
    fi

    if [ "$(md5sum < "$DEFAULT_CONF_FILE")" != "$(md5sum < "$DEFAULT_CONF_SHIPPED")" ]; then
        entrypoint_log "$ME: info: $DEFAULT_CONF_FILE differs from the shipped default config"
        return 0
    fi

    sed -i 's,listen       80;,listen       80;\n    listen       [::]:80;,' "$DEFAULT_CONF_FILE"

    entrypoint_log "$ME: info: Enabled listen on IPv6 in $DEFAULT_CONF_FILE"
}

enable_ipv6_listen

exec "$@"
