import base64
import logging
import os
import time

import pyDes

from gluulib import get_manager

manager = get_manager()

logger = logging.getLogger("jks_sync")
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
fmt = logging.Formatter('%(levelname)s - %(asctime)s - %(message)s')
ch.setFormatter(fmt)
logger.addHandler(ch)

# delay between JKS sync (in seconds)
GLUU_SYNC_JKS_INTERVAL = os.environ.get("GLUU_SYNC_JKS_INTERVAL", 30)


def jks_created():
    encoded_salt = ""

    with open("/etc/gluu/conf/salt") as f:
        txt = f.read()
        encoded_salt = txt.split("=")[-1].strip()

    jks = decrypt_text(manager.secret.get("oxauth_jks_base64"), encoded_salt)

    with open(manager.config.get("oxauth_openid_jks_fn"), "wb") as fd:
        fd.write(jks)
        return True
    return False


def should_sync_jks():
    last_rotation = manager.config.get("oxauth_key_rotated_at")

    # keys are not rotated yet
    if not last_rotation:
        return False

    # check modification time of local JKS
    try:
        mtime = int(os.path.getmtime(manager.config.get("oxauth_openid_jks_fn")))
    except OSError:
        mtime = 0

    return mtime < int(last_rotation)


def sync_jks():
    if jks_created():
        logger.info("oxauth-keys.jks has been synchronized")
        return True

    # mark sync as failed
    return False


def decrypt_text(encrypted_text, key):
    cipher = pyDes.triple_des(b"{}".format(key), pyDes.ECB,
                              padmode=pyDes.PAD_PKCS5)
    encrypted_text = b"{}".format(base64.b64decode(encrypted_text))
    return cipher.decrypt(encrypted_text)


def main():
    try:
        sync_interval = int(GLUU_SYNC_JKS_INTERVAL)
        # if value is lower than 1, use default
        if sync_interval < 1:
            sync_interval = 30
    except ValueError:
        sync_interval = 30

    try:
        while True:
            try:
                if should_sync_jks():
                    sync_jks()
            except Exception as exc:
                logger.warn("got unhandled error; reason={}".format(exc))

            # sane interval
            time.sleep(sync_interval)
    except KeyboardInterrupt:
        logger.warn("canceled by user; exiting ...")


if __name__ == "__main__":
    main()
