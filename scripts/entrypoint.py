import base64
import os
import re
import shlex
import subprocess

import pyDes

from gluulib import get_manager

GLUU_LDAP_URL = os.environ.get("GLUU_LDAP_URL", "localhost:1636")
GLUU_COUCHBASE_URL = os.environ.get("GLUU_COUCHBASE_URL", "localhost")
GLUU_PERSISTENCE_TYPE = os.environ.get("GLUU_PERSISTENCE_TYPE", "ldap")

manager = get_manager()


def render_salt():
    encode_salt = manager.secret.get("encoded_salt")

    with open("/app/templates/salt.tmpl") as fr:
        txt = fr.read()
        with open("/etc/gluu/conf/salt", "w") as fw:
            rendered_txt = txt % {"encode_salt": encode_salt}
            fw.write(rendered_txt)


def render_ldap_properties():
    with open("/app/templates/gluu-ldap.properties.tmpl") as fr:
        txt = fr.read()

        ldap_hostname, ldaps_port = GLUU_LDAP_URL.split(":")

        with open("/etc/gluu/conf/gluu-ldap.properties", "w") as fw:
            rendered_txt = txt % {
                "ldap_binddn": manager.config.get("ldap_binddn"),
                "encoded_ox_ldap_pw": manager.secret.get("encoded_ox_ldap_pw"),
                "ldap_hostname": ldap_hostname,
                "ldaps_port": ldaps_port,
                "ldapTrustStoreFn": manager.config.get("ldapTrustStoreFn"),
                "encoded_ldapTrustStorePass": manager.secret.get("encoded_ldapTrustStorePass"),
            }
            fw.write(rendered_txt)


def render_couchbase_properties():
    # buckets: gluu_cache, gluu_site
    couchbase_buckets = [
        "gluu",
        "gluu_user",
        "gluu_statistic",
        "gluu_cache",
        "gluu_site",
    ]

    # bucket.default: gluu
    # bucket.gluu_cache.mapping: cache
    # bucket.gluu_statistic.mapping: statistic
    # bucket.gluu_site.mapping: site
    couchbase_mappings = [
        "bucket.gluu_user.mapping: people, groups",
        "bucket.gluu_cache.mapping: cache",
        "bucket.gluu_statistic.mapping: statistic",
        "bucket.gluu_site.mapping: site",
    ]

    with open("/app/templates/gluu-couchbase.properties.tmpl") as fr:
        txt = fr.read()

        ldap_hostname, ldaps_port = GLUU_LDAP_URL.split(":")

        with open("/etc/gluu/conf/gluu-couchbase.properties", "w") as fw:
            rendered_txt = txt % {
                "hostname": GLUU_COUCHBASE_URL,
                "couchbase_server_user": manager.config.get("couchbase_server_user"),
                "encoded_couchbase_server_pw": manager.secret.get("encoded_couchbase_server_pw"),
                "couchbase_buckets": ", ".join(couchbase_buckets),
                "default_bucket": "gluu",
                "couchbase_mappings": "\n".join(couchbase_mappings),
                "encryption_method": "SSHA-256",
                "ssl_enabled": "true",
                "couchbaseTrustStoreFn": manager.config.get("couchbaseTrustStoreFn"),
                "encoded_couchbaseTrustStorePass": manager.secret.get("encoded_couchbaseTrustStorePass"),
            }
            fw.write(rendered_txt)


def render_gluu_properties():
    with open("/app/templates/gluu.properties.tmpl") as fr:
        txt = fr.read()

        ldap_hostname, ldaps_port = GLUU_LDAP_URL.split(":")

        with open("/etc/gluu/conf/gluu.properties", "w") as fw:
            rendered_txt = txt % {
                "gluuOptPythonFolder": "/opt/gluu/python",
                "certFolder": "/etc/certs",
                "persistence_type": GLUU_PERSISTENCE_TYPE,
            }
            fw.write(rendered_txt)


def decrypt_text(encrypted_text, key):
    cipher = pyDes.triple_des(b"{}".format(key), pyDes.ECB,
                              padmode=pyDes.PAD_PKCS5)
    encrypted_text = b"{}".format(base64.b64decode(encrypted_text))
    return cipher.decrypt(encrypted_text)


def sync_ldap_pkcs12():
    pkcs = decrypt_text(manager.secret.get("ldap_pkcs12_base64"),
                        manager.secret.get("encoded_salt"))

    with open(manager.config.get("ldapTrustStoreFn"), "wb") as fw:
        fw.write(pkcs)


def exec_cmd(cmd):
    args = shlex.split(cmd)
    popen = subprocess.Popen(args,
                             stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE)
    stdout, stderr = popen.communicate()
    retcode = popen.returncode
    return stdout, stderr, retcode


def sync_couchbase_pkcs12():
    with open(manager.config.get("couchbaseTrustStoreFn"), "wb") as fw:
        encoded_pkcs = manager.secret.get("couchbase_pkcs12_base64")
        pkcs = decrypt_text(encoded_pkcs, manager.secret.get("encoded_salt"))
        fw.write(pkcs)


def render_ssl_cert():
    ssl_cert = manager.secret.get("ssl_cert")
    if ssl_cert:
        with open("/etc/certs/gluu_https.crt", "w") as fd:
            fd.write(ssl_cert)


def render_ssl_key():
    ssl_key = manager.secret.get("ssl_key")
    if ssl_key:
        with open("/etc/certs/gluu_https.key", "w") as fd:
            fd.write(ssl_key)


def render_idp_signing():
    cert = manager.secret.get("idp3SigningCertificateText")
    if cert:
        with open("/etc/certs/idp-signing.crt", "w") as fd:
            fd.write(cert)


def render_passport_rp_jks():
    jks = decrypt_text(manager.secret.get("passport_rp_jks_base64"),
                       manager.secret.get("encoded_salt"))

    if jks:
        with open("/etc/certs/passport-rp.jks", "w") as fd:
            fd.write(jks)


def modify_jetty_xml():
    fn = "/opt/jetty/etc/jetty.xml"
    with open(fn) as f:
        txt = f.read()

    # disable contexts
    updates = re.sub(
        r'<New id="DefaultHandler" class="org.eclipse.jetty.server.handler.DefaultHandler"/>',
        r'<New id="DefaultHandler" class="org.eclipse.jetty.server.handler.DefaultHandler">\n\t\t\t\t <Set name="showContexts">false</Set>\n\t\t\t </New>',
        txt,
        flags=re.DOTALL | re.M,
    )

    # disable Jetty version info
    updates = re.sub(
        r'(<Set name="sendServerVersion"><Property name="jetty.httpConfig.sendServerVersion" deprecated="jetty.send.server.version" default=")true(" /></Set>)',
        r'\1false\2',
        updates,
        flags=re.DOTALL | re.M,
    )

    with open(fn, "w") as f:
        f.write(updates)


def modify_webdefault_xml():
    fn = "/opt/jetty/etc/webdefault.xml"
    with open(fn) as f:
        txt = f.read()

    # disable dirAllowed
    updates = re.sub(
        r'(<param-name>dirAllowed</param-name>)(\s*)(<param-value>)true(</param-value>)',
        r'\1\2\3false\4',
        txt,
        flags=re.DOTALL | re.M,
    )

    with open(fn, "w") as f:
        f.write(updates)


def encrypt_text(text, key):
    cipher = pyDes.triple_des(b"{}".format(key), pyDes.ECB,
                              padmode=pyDes.PAD_PKCS5)
    encrypted_text = cipher.encrypt(b"{}".format(text))
    return base64.b64encode(encrypted_text)


if __name__ == "__main__":
    render_salt()
    render_gluu_properties()
    render_ldap_properties()
    render_couchbase_properties()
    render_ssl_cert()
    render_ssl_key()
    sync_ldap_pkcs12()
    sync_couchbase_pkcs12()
    render_idp_signing()
    render_passport_rp_jks()
    modify_jetty_xml()
    modify_webdefault_xml()
