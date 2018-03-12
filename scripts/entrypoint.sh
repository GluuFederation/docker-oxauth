#!/bin/bash
set -e

download_custom_tar() {
    if [ ! -z ${GLUU_CUSTOM_OXAUTH_URL} ]; then
        mkdir -p /tmp/oxauth
        wget -q ${GLUU_CUSTOM_OXAUTH_URL} -O /tmp/oxauth/custom-oxauth.tar.gz
        cd /tmp/oxauth
        tar xf custom-oxauth.tar.gz

        if [ -d /tmp/oxauth/pages ]; then
            cp -R /tmp/oxauth/pages/ /opt/gluu/jetty/oxauth/custom/
        fi

        if [ -d /tmp/oxauth/static ]; then
            cp -R /tmp/oxauth/static/ /opt/gluu/jetty/oxauth/custom/
        fi

        if [ -d /tmp/oxauth/lib/ext ]; then
            cp -R /tmp/oxauth/lib/ext/ /opt/gluu/jetty/oxauth/lib/
        fi
    fi
}

prepare_jks_sync_env() {
    echo "export GLUU_KV_HOST=${GLUU_KV_HOST}" > /opt/jks_sync/env
    echo "export GLUU_KV_PORT=${GLUU_KV_PORT}" >> /opt/jks_sync/env
}


if [ ! -f /touched ]; then
    download_custom_tar
    python /opt/scripts/entrypoint.py
    touch /touched
fi

# run JKS sync as background job
prepare_jks_sync_env
cron

cd /opt/gluu/jetty/oxauth


get_java_opts() {
    local java_opts="
      -server
      -Xms256m
      -Xmx4096m
      -XX:+DisableExplicitGC
      -Dgluu.base=/etc/gluu
      -Dserver.base=/opt/gluu/jetty/oxauth
      -Dlog.base=/opt/gluu/jetty/oxauth
      -Dpython.home=/opt/jython
    "

    if [ -n "${GLUU_DEBUG_PORT}" ]; then
        java_opts="
            ${java_opts}
            -agentlib:jdwp=transport=dt_socket,address=${GLUU_DEBUG_PORT},server=y,suspend=n
        "
    fi

    echo "${java_opts}"
}

exec gosu \
     root \
     java $(get_java_opts) \
     -jar /opt/jetty/start.jar
