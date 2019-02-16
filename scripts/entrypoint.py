import base64
import os

import pyDes

from gluulib import get_manager

GLUU_LDAP_URL = os.environ.get("GLUU_LDAP_URL", "localhost:1636")

manager = get_manager()


def render_salt():
    encode_salt = manager.secret.get("encoded_salt")

    with open("/opt/templates/salt.tmpl") as fr:
        txt = fr.read()
        with open("/etc/gluu/conf/salt", "w") as fw:
            rendered_txt = txt % {"encode_salt": encode_salt}
            fw.write(rendered_txt)


def render_ldap_properties():
    with open("/opt/templates/ox-ldap.properties.tmpl") as fr:
        txt = fr.read()

        with open("/etc/gluu/conf/ox-ldap.properties", "w") as fw:
            rendered_txt = txt % {
                "ldap_binddn": manager.config.get("ldap_binddn"),
                "encoded_ox_ldap_pw": manager.secret.get("encoded_ox_ldap_pw"),
                "inumAppliance": manager.config.get("inumAppliance"),
                "ldap_url": GLUU_LDAP_URL,
                "ldapTrustStoreFn": manager.config.get("ldapTrustStoreFn"),
                "encoded_ldapTrustStorePass": manager.secret.get("encoded_ldapTrustStorePass")
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


if __name__ == "__main__":
    render_salt()
    render_ldap_properties()
    render_ssl_cert()
    render_ssl_key()
    sync_ldap_pkcs12()
    render_idp_signing()
    render_passport_rp_jks()
