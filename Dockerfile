FROM openjdk:jre-alpine

LABEL maintainer="Gluu Inc. <support@gluu.org>"

# ===============
# Alpine packages
# ===============

RUN apk update && apk add --no-cache \
    py-pip \
    openssl

# =====
# Jetty
# =====

ENV JETTY_VERSION 9.3.15.v20161220
ENV JETTY_TGZ_URL https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-distribution/${JETTY_VERSION}/jetty-distribution-${JETTY_VERSION}.tar.gz
ENV JETTY_HOME /opt/jetty
ENV JETTY_BASE /opt/gluu/jetty
ENV JETTY_USER_HOME_LIB /home/jetty/lib

# Install jetty
RUN wget -q ${JETTY_TGZ_URL} -O /tmp/jetty.tar.gz \
    && mkdir -p /opt \
    && tar -xzf /tmp/jetty.tar.gz -C /opt \
    && mv /opt/jetty-distribution-${JETTY_VERSION} ${JETTY_HOME} \
    && rm -rf /tmp/jetty.tar.gz \
    && mv ${JETTY_HOME}/etc/webdefault.xml ${JETTY_HOME}/etc/webdefault.xml.bak \
    && mv ${JETTY_HOME}/etc/jetty.xml ${JETTY_HOME}/etc/jetty.xml.bak

COPY jetty/webdefault.xml ${JETTY_HOME}/etc/
COPY jetty/jetty.xml ${JETTY_HOME}/etc/

# Ports required by jetty
EXPOSE 8080

# ======
# Jython
# ======

ENV JYTHON_VERSION 2.7.0
ENV JYTHON_DOWNLOAD_URL http://central.maven.org/maven2/org/python/jython-standalone/${JYTHON_VERSION}/jython-standalone-${JYTHON_VERSION}.jar

# Install Jython
RUN wget -q ${JYTHON_DOWNLOAD_URL} -O /tmp/jython.jar \
    && mkdir -p /opt/jython \
    && unzip -q /tmp/jython.jar -d /opt/jython \
    && rm -f /tmp/jython.jar

# ======
# oxAuth
# ======

ENV OX_VERSION 3.1.2.Final
ENV OX_BUILD_DATE 2018-01-18
ENV OXAUTH_DOWNLOAD_URL https://ox.gluu.org/maven/org/xdi/oxauth-server/${OX_VERSION}/oxauth-server-${OX_VERSION}.war

# the LABEL defined before downloading ox war/jar files to make sure
# it gets the latest build for specific version
LABEL vendor="Gluu Federation" \
      org.gluu.oxauth-server.version="${OX_VERSION}" \
      org.gluu.oxauth-server.build-date="${OX_BUILD_DATE}"

# Install oxAuth
RUN wget -q ${OXAUTH_DOWNLOAD_URL} -O /tmp/oxauth.war \
    && mkdir -p ${JETTY_BASE}/oxauth/webapps/oxauth \
    && unzip -qq /tmp/oxauth.war -d ${JETTY_BASE}/oxauth/webapps/oxauth \
    && java -jar ${JETTY_HOME}/start.jar jetty.home=${JETTY_HOME} jetty.base=${JETTY_BASE}/oxauth --add-to-start=deploy,http,jsp,servlets,ext,http-forwarded,websocket \
    && rm -f /tmp/oxauth.war \
    && mv ${JETTY_BASE}/oxauth/webapps/oxauth/WEB-INF/web.xml ${JETTY_BASE}/oxauth/webapps/oxauth/WEB-INF/web.xml.bak

COPY jetty/web.xml ${JETTY_BASE}/oxauth/webapps/oxauth/WEB-INF/

# ======
# Python
# ======

COPY requirements.txt /tmp/requirements.txt
RUN pip install -U pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

# ==========
# misc stuff
# ==========
RUN mkdir -p /etc/certs \
    && mkdir -p /opt/gluu/python/libs \
    && mkdir -p ${JETTY_BASE}/oxauth/custom/pages ${JETTY_BASE}/oxauth/custom/static \
    && mkdir -p /etc/gluu/conf \
    && mkdir -p /opt/templates

COPY libs /opt/gluu/python/libs
COPY certs /etc/certs
COPY jetty/oxauth_web_resources.xml ${JETTY_BASE}/oxauth/webapps/
COPY conf/ox-ldap.properties.tmpl /opt/templates/
COPY conf/salt.tmpl /opt/templates/

ENV GLUU_LDAP_URL localhost:1636
ENV GLUU_KV_HOST localhost
ENV GLUU_KV_PORT 8500
ENV GLUU_CUSTOM_OXAUTH_URL ""

VOLUME ${JETTY_BASE}/oxauth/custom/pages
VOLUME ${JETTY_BASE}/oxauth/custom/static
VOLUME ${JETTY_BASE}/oxauth/lib/ext
VOLUME ${JETTY_BASE}/oxauth/logs

COPY scripts /opt/scripts
RUN chmod +x /opt/scripts/entrypoint.sh
CMD ["/opt/scripts/wait-for-it", "/opt/scripts/entrypoint.sh"]
