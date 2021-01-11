#!/bin/sh
set -e


# ========
# Profiler
# ========
profiler_opt=""
if [ "${GLUU_JAVA_PROFILER}" = true ]; then
    profiler_opt="-agentpath:/usr/local/YourKit-JavaProfiler-2020.9/bin/linux-x86-64/libyjpagent.so=port=10001,listen=all"
    # ========
    # jattach
    # ========

    apk add --no-cache jattach --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/

    # ============================
    # YourKit Java Profiler agents
    # ============================

    wget https://www.yourkit.com/download/docker/YourKit-JavaProfiler-2020.9-docker.zip -P /tmp/ && \
    unzip /tmp/YourKit-JavaProfiler-2020.9-docker.zip -d /usr/local && \
    rm /tmp/YourKit-JavaProfiler-2020.9-docker.zip && \
    LD_LIBRARY_PATH=/lib64
    if [ -n "${GLUU_JAVA_PROFILER_PORT}" ]; then
        profiler_opt="
            -agentpath:/usr/local/YourKit-JavaProfiler-2020.9/bin/linux-x86-64/libyjpagent.so=port=${GLUU_JAVA_PROFILER_PORT},listen=all
        "
    fi
fi

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

move_builtin_jars() {
    # move twilio lib
    if [ ! -f /opt/gluu/jetty/oxauth/custom/libs/twilio.jar ]; then
        mkdir -p /opt/gluu/jetty/oxauth/custom/libs
        mv /usr/share/java/twilio.jar /opt/gluu/jetty/oxauth/custom/libs/twilio.jar
    fi

    # move jsmpp lib
    if [ ! -f /opt/gluu/jetty/oxauth/custom/libs/jsmpp.jar ]; then
        mkdir -p /opt/gluu/jetty/oxauth/custom/libs
        mv /usr/share/java/jsmpp.jar /opt/gluu/jetty/oxauth/custom/libs/jsmpp.jar
    fi
}

# ==========
# ENTRYPOINT
# ==========

move_builtin_jars
python3 /app/scripts/wait.py

if [ ! -f /deploy/touched ]; then
    python3 /app/scripts/entrypoint.py
    touch /deploy/touched
fi

python3 /app/scripts/jks_sync.py &
python3 /app/scripts/jca_sync.py &
python3 /app/scripts/mod_context.py

# run oxAuth server
cd /opt/gluu/jetty/oxauth
mkdir -p /opt/jetty/temp
exec java \
    -server \
    -XX:+DisableExplicitGC \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=$GLUU_MAX_RAM_PERCENTAGE \
    -Dgluu.base=/etc/gluu \
    -Dserver.base=/opt/gluu/jetty/oxauth \
    -Dlog.base=/opt/gluu/jetty/oxauth \
    -Dpython.home=/opt/jython \
    -Djava.io.tmpdir=/opt/jetty/temp \
    ${profiler_opt} \
    $(get_debug_opt) \
    ${GLUU_JAVA_OPTIONS} \
    -jar /opt/jetty/start.jar
