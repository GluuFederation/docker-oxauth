#!/bin/sh
set -e

# =========
# FUNCTIONS
# =========

get_java_opts() {
    local java_opts="
        -XX:+DisableExplicitGC \
        -XX:+UseContainerSupport \
        -XX:MaxRAMPercentage=$GLUU_MAX_RAM_PERCENTAGE \
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

# ==========
# ENTRYPOINT
# ==========

cat << LICENSE_ACK

# ================================================================================================ #
# Gluu License Agreement: https://github.com/GluuFederation/enterprise-edition/blob/4.0.0/LICENSE. #
# The use of Gluu Server Enterprise Edition is subject to the Gluu Support License.                #
# ================================================================================================ #

LICENSE_ACK

# check persistence type
case "${GLUU_PERSISTENCE_TYPE}" in
    ldap|couchbase|hybrid)
        ;;
    *)
        echo "unsupported GLUU_PERSISTENCE_TYPE value; please choose 'ldap', 'couchbase', or 'hybrid'"
        exit 1
        ;;
esac

# check mapping used by LDAP
if [ "${GLUU_PERSISTENCE_TYPE}" = "hybrid" ]; then
    case "${GLUU_PERSISTENCE_LDAP_MAPPING}" in
        default|user|cache|site|token)
            ;;
        *)
            echo "unsupported GLUU_PERSISTENCE_LDAP_MAPPING value; please choose 'default', 'user', 'cache', 'site', or 'token'"
            exit 1
            ;;
    esac
fi

# run wait_for functions
deps="config,secret"

if [ "${GLUU_PERSISTENCE_TYPE}" = "hybrid" ]; then
    deps="${deps},ldap,couchbase"
else
    deps="${deps},${GLUU_PERSISTENCE_TYPE}"
fi

if [ -f /etc/redhat-release ]; then
    source scl_source enable python27 && gluu-wait --deps="$deps"
else
    gluu-wait --deps="$deps"
fi

# run Python entrypoint
if [ ! -f /deploy/touched ]; then
    if [ -f /etc/redhat-release ]; then
        source scl_source enable python27 && python /app/scripts/entrypoint.py
    else
        python /app/scripts/entrypoint.py
    fi
    touch /deploy/touched
fi

if [ -f /etc/redhat-release ]; then
    source scl_source enable python27 && python /app/scripts/jks_sync.py &
else
    python /app/scripts/jks_sync.py &
fi

# if persistence type includes LDAP, make sure add delay to wait LDAP
# to avoid broken connection when oxAuth tries to check entries in startup
case $GLUU_PERSISTENCE_TYPE in
    ldap|hybrid)
        sleep 10
        ;;
esac

# run oxAuth server
cd /opt/gluu/jetty/oxauth
exec java \
    $(get_java_opts) \
    -jar /opt/jetty/start.jar -server
