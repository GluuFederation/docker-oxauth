FROM openjdk:8-jre-alpine3.9

LABEL maintainer="Gluu Inc. <support@gluu.org>"

# ===============
# Alpine packages
# ===============

RUN apk update && apk add --no-cache \
    openssl \
    py-pip \
    shadow \
    wget

# =====
# Jetty
# =====

ENV JETTY_VERSION 9.4.15.v20190215
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
    && cp ${JETTY_HOME}/etc/webdefault.xml ${JETTY_HOME}/etc/webdefault.xml.bak \
    && cp ${JETTY_HOME}/etc/jetty.xml ${JETTY_HOME}/etc/jetty.xml.bak

# Ports required by jetty
EXPOSE 8080

# ======
# Jython
# ======

ENV JYTHON_VERSION 2.7.2a1
ENV JYTHON_DOWNLOAD_URL https://ox.gluu.org/dist/jython/${JYTHON_VERSION}/jython-installer.jar
RUN wget -q ${JYTHON_DOWNLOAD_URL} -O /tmp/jython-installer.jar \
    && mkdir -p /opt/jython \
    && java -jar /tmp/jython-installer.jar -v -s -d /opt/jython -t standard -e ensurepip \
    && rm -f /tmp/jython-installer.jar

# ======
# oxAuth
# ======

ENV OX_VERSION 4.0.0-SNAPSHOT
ENV OX_BUILD_DATE 2019-05-07
ENV OXAUTH_DOWNLOAD_URL https://ox.gluu.org/maven/org/gluu/oxauth-server/${OX_VERSION}/oxauth-server-${OX_VERSION}.war

# the LABEL defined before downloading ox war/jar files to make sure
# it gets the latest build for specific version
LABEL vendor="Gluu Federation" \
      org.gluu.oxauth-server.version="${OX_VERSION}" \
      org.gluu.oxauth-server.build-date="${OX_BUILD_DATE}"

# Install oxAuth
RUN wget -q ${OXAUTH_DOWNLOAD_URL} -O /tmp/oxauth.war \
    && mkdir -p ${JETTY_BASE}/oxauth/webapps/oxauth \
    && unzip -qq /tmp/oxauth.war -d ${JETTY_BASE}/oxauth/webapps/oxauth \
    && java -jar ${JETTY_HOME}/start.jar jetty.home=${JETTY_HOME} jetty.base=${JETTY_BASE}/oxauth --add-to-start=server,deploy,annotations,resources,http,http-forwarded,threadpool,jsp,ext,websocket \
    && rm -f /tmp/oxauth.war

# ===========
# Custom libs
# ===========

ENV TWILIO_VERSION 7.17.6
RUN mkdir -p ${JETTY_BASE}/oxauth/custom/libs
RUN wget -q https://repo1.maven.org/maven2/com/twilio/sdk/twilio/${TWILIO_VERSION}/twilio-${TWILIO_VERSION}.jar -O ${JETTY_BASE}/oxauth/custom/libs/twilio-${TWILIO_VERSION}.jar

# ====
# Tini
# ====

ENV TINI_VERSION v0.18.0
RUN wget -q https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static -O /usr/bin/tini \
    && chmod +x /usr/bin/tini

# ======
# Python
# ======

COPY requirements.txt /tmp/requirements.txt
RUN pip install -U pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

# =======
# License
# =======

RUN mkdir -p /licenses
COPY LICENSE /licenses/

# ==========
# misc stuff
# ==========

RUN mkdir -p /etc/certs /deploy \
    /opt/gluu/python/libs \
    ${JETTY_BASE}/oxauth/custom/pages ${JETTY_BASE}/oxauth/custom/static \
    ${JETTY_BASE}/oxauth/custom/i18n \
    /etc/gluu/conf \
    /opt/templates

COPY libs /opt/gluu/python/libs
COPY certs /etc/certs
COPY jetty/oxauth_web_resources.xml ${JETTY_BASE}/oxauth/webapps/
COPY conf/gluu-ldap.properties.tmpl /opt/templates/
COPY conf/salt.tmpl /opt/templates/
COPY conf/fido2 /etc/gluu/conf/fido2
RUN mkdir -p /etc/gluu/conf/fido2/mds/cert \
    /etc/gluu/conf/fido2/mds/toc \
    /etc/gluu/conf/fido2/server_metadata

# ==========
# Config ENV
# ==========

ENV GLUU_CONFIG_ADAPTER consul
ENV GLUU_CONFIG_CONSUL_HOST localhost
ENV GLUU_CONFIG_CONSUL_PORT 8500
ENV GLUU_CONFIG_CONSUL_CONSISTENCY stale
ENV GLUU_CONFIG_CONSUL_SCHEME http
ENV GLUU_CONFIG_CONSUL_VERIFY false
ENV GLUU_CONFIG_CONSUL_CACERT_FILE /etc/certs/consul_ca.crt
ENV GLUU_CONFIG_CONSUL_CERT_FILE /etc/certs/consul_client.crt
ENV GLUU_CONFIG_CONSUL_KEY_FILE /etc/certs/consul_client.key
ENV GLUU_CONFIG_CONSUL_TOKEN_FILE /etc/certs/consul_token
ENV GLUU_CONFIG_KUBERNETES_NAMESPACE default
ENV GLUU_CONFIG_KUBERNETES_CONFIGMAP gluu
ENV GLUU_CONFIG_KUBERNETES_USE_KUBE_CONFIG false

# ==========
# Secret ENV
# ==========

ENV GLUU_SECRET_ADAPTER vault
ENV GLUU_SECRET_VAULT_SCHEME http
ENV GLUU_SECRET_VAULT_HOST localhost
ENV GLUU_SECRET_VAULT_PORT 8200
ENV GLUU_SECRET_VAULT_VERIFY false
ENV GLUU_SECRET_VAULT_ROLE_ID_FILE /etc/certs/vault_role_id
ENV GLUU_SECRET_VAULT_SECRET_ID_FILE /etc/certs/vault_secret_id
ENV GLUU_SECRET_VAULT_CERT_FILE /etc/certs/vault_client.crt
ENV GLUU_SECRET_VAULT_KEY_FILE /etc/certs/vault_client.key
ENV GLUU_SECRET_VAULT_CACERT_FILE /etc/certs/vault_ca.crt
ENV GLUU_SECRET_KUBERNETES_NAMESPACE default
ENV GLUU_SECRET_KUBERNETES_SECRET gluu
ENV GLUU_SECRET_KUBERNETES_USE_KUBE_CONFIG false

# ===========
# Generic ENV
# ===========

ENV GLUU_LDAP_URL localhost:1636
ENV GLUU_MAX_RAM_FRACTION 1
ENV GLUU_WAIT_MAX_TIME 300
ENV GLUU_WAIT_SLEEP_DURATION 5
ENV GLUU_JKS_SYNC_INTERVAL 30
ENV PYTHON_HOME /opt/jython

COPY scripts /opt/scripts
RUN chmod +x /opt/scripts/entrypoint.sh

# # create non-root user
# RUN useradd -ms /bin/sh --uid 1000 jetty \
#     && usermod -a -G root jetty

# # adjust ownership
# RUN chown -R 1000:1000 /opt/gluu/jetty \
#     && chown -R 1000:1000 /deploy \
#     && chmod -R g+w /usr/lib/jvm/default-jvm/jre/lib/security/cacerts \
#     && chgrp -R 0 /opt/gluu/jetty && chmod -R g=u /opt/gluu/jetty \
#     && chgrp -R 0 /deploy && chmod -R g=u /deploy \
#     && chgrp -R 0 /etc/certs && chmod -R g=u /etc/certs \
#     && chgrp -R 0 /etc/gluu && chmod -R g=u /etc/gluu

# # run as non-root user
# USER 1000

ENTRYPOINT ["tini", "-g", "--"]
CMD ["/opt/scripts/entrypoint.sh"]
