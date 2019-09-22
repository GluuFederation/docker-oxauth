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

run_entrypoint() {
    if [ ! -f /deploy/touched ]; then
        python /app/scripts/entrypoint.py
        touch /deploy/touched
    fi
}

run_jks_sync() {
    python /app/scripts/jks_sync.py &
}

# ==========
# ENTRYPOINT
# ==========

cat << LICENSE_ACK

# ================================================================================================ #
# Gluu License Agreement: https://github.com/GluuFederation/enterprise-edition/blob/4.0.0/LICENSE. #
# The use of Gluu Server Enterprise Edition is subject to the Gluu Support License.                #
# ================================================================================================ #

LICENSE_ACK

if [ -f /etc/redhat-release ]; then
    source scl_source enable python27 && run_wait
    source scl_source enable python27 && run_entrypoint
    source scl_source enable python27 && run_jks_sync
else
    run_wait
    run_entrypoint
    run_jks_sync
fi

# run oxAuth server
cd /opt/gluu/jetty/oxauth
exec java \
    -server \
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
