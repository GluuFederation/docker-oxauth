#!/bin/sh
set -e

# =========
# FUNCTIONS
# =========

get_debug_opt() {
    debug_opt=""
    if [ -n "${GLUU_DEBUG_PORT}" ]; then
        debug_opt="
            -agentlib:jdwp=transport=dt_socket,address=${GLUU_DEBUG_PORT},server=y,suspend=n
        "
    fi
    echo "${debug_opt}"
}

run_wait() {
    python /app/scripts/wait.py
}

move_builtin_jars() {
    # move twilio lib
    if [ ! -f /opt/gluu/jetty/oxauth/custom/libs/twilio.jar ]; then
        mkdir -p /opt/gluu/jetty/oxauth/custom/libs
        mv /tmp/twilio.jar /opt/gluu/jetty/oxauth/custom/libs/twilio.jar
    fi

    # move jsmpp lib
    if [ ! -f /opt/gluu/jetty/oxauth/custom/libs/jsmpp.jar ]; then
        mkdir -p /opt/gluu/jetty/oxauth/custom/libs
        mv /tmp/jsmpp.jar /opt/gluu/jetty/oxauth/custom/libs/jsmpp.jar
    fi
}

run_entrypoint() {
    if [ ! -f /deploy/touched ]; then
        python /app/scripts/entrypoint.py
        touch /deploy/touched
    fi
}

run_jks_sync() {
    python /app/scripts/jks_sync.py &
}

run_jca_sync() {
    python3 /app/scripts/jca_sync.py &
}

run_casawatcher() {
    python /app/scripts/casawatcher.py &
}

run_mod_context() {
    python3 /app/scripts/mod_context.py
}

# ==========
# ENTRYPOINT
# ==========

move_builtin_jars

if [ -f /etc/redhat-release ]; then
    source scl_source enable python27 && run_wait
    source scl_source enable python3 && run_jca_sync
    source scl_source enable python27 && run_entrypoint
    source scl_source enable python27 && run_jks_sync
    source scl_source enable python27 && run_casawatcher
    source scl_source enable python27 && run_mod_context
else
    run_wait
    run_jca_sync
    run_entrypoint
    run_jks_sync
    run_casawatcher
    run_mod_context
fi

# run oxAuth server
cd /opt/gluu/jetty/oxauth
exec java \
    -server \
    -Xms1024m \
    -Xmx1536m \
    -XX:+DisableExplicitGC \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=$GLUU_MAX_RAM_PERCENTAGE \
    -Dgluu.base=/etc/gluu \
    -Dserver.base=/opt/gluu/jetty/oxauth \
    -Dlog.base=/opt/gluu/jetty/oxauth \
    -Dpython.home=/opt/jython \
    -Djava.io.tmpdir=/tmp \
    $(get_debug_opt) \
    -jar /opt/jetty/start.jar
