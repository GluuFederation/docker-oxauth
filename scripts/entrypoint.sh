#!/bin/sh
set -e

import_ssl_cert() {
    if [ -f /etc/certs/gluu_https.crt ]; then
        openssl x509 -outform der -in /etc/certs/gluu_https.crt -out /etc/certs/gluu_https.der
        keytool -importcert -trustcacerts \
            -alias gluu_https \
            -file /etc/certs/gluu_https.der \
            -keystore /usr/lib/jvm/default-jvm/jre/lib/security/cacerts \
            -storepass changeit \
            -noprompt
    fi
}

get_java_opts() {
    local java_opts="
        -server \
        -XX:+UnlockExperimentalVMOptions \
        -XX:+UseCGroupMemoryLimitForHeap \
        -XX:MaxRAMFraction=$GLUU_MAX_RAM_FRACTION \
        -XX:+DisableExplicitGC \
        -Dgluu.base=/etc/gluu \
        -Dserver.base=/opt/gluu/jetty/oxauth \
        -Dlog.base=/opt/gluu/jetty/oxauth \
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

if [ ! -f /deploy/touched ]; then
    # backward-compat
    if [ -f /touched ]; then
        mv /touched /deploy/touched
    else
        # @TODO: wait_for config & secret
        if [ -f /etc/redhat-release ]; then
            source scl_source enable python27 && python /opt/scripts/wait_for.py --deps="config,secret" && python /opt/scripts/entrypoint.py
        else
            python /opt/scripts/wait_for.py --deps="config,secret" && python /opt/scripts/entrypoint.py
        fi

        import_ssl_cert
        touch /deploy/touched
    fi
fi

if [ -f /etc/redhat-release ]; then
    source scl_source enable python27 && python /opt/scripts/wait_for.py --deps="ldap"
    # @TODO: enable after auto-unseal is ready
    # source scl_source enable python27 && python /opt/scripts/jks_sync.py &
else
    python /opt/scripts/wait_for.py --deps="ldap"
    # @TODO: enable after auto-unseal is ready
    # python /opt/scripts/jks_sync.py &
fi

cd /opt/gluu/jetty/oxauth
exec java \
    $(get_java_opts) \
    -jar /opt/jetty/start.jar
