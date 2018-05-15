import base64
import logging
import os
import time

import consulate
import pyDes
from requests.exceptions import ConnectionError

GLUU_KV_HOST = os.environ.get("GLUU_KV_HOST", "localhost")
GLUU_KV_PORT = os.environ.get("GLUU_KV_PORT", 8500)

consul = consulate.Consul(host=GLUU_KV_HOST, port=GLUU_KV_PORT)

logger = logging.getLogger("jks_sync")
logger.setLevel(logging.INFO)
ch = logging.StreamHandler()
fmt = logging.Formatter('%(levelname)s - %(asctime)s - %(message)s')
ch.setFormatter(fmt)
logger.addHandler(ch)

CONFIG_PREFIX = "gluu/config/"


def merge_path(name):
    # example: `hostname` renamed to `gluu/config/hostname`
    return "".join([CONFIG_PREFIX, name])


def unmerge_path(name):
    # example: `gluu/config/hostname` renamed to `hostname`
    return name[len(CONFIG_PREFIX):]


def get_config(name, default=None):
    return consul.kv.get(merge_path(name), default)


def jks_created():
    jks = decrypt_text(get_config("oxauth_jks_base64"), get_config("encoded_salt"))

    with open(get_config("oxauth_openid_jks_fn"), "wb") as fd:
        fd.write(jks)
        return True
    return False


def should_sync_jks():
    last_rotation = get_config("oxauth_key_rotated_at")

    # keys are not rotated yet
    if not last_rotation:
        return False

    # check modification time of local JKS
    try:
        mtime = int(os.path.getmtime(get_config("oxauth_openid_jks_fn")))
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
        while True:
            try:
                if should_sync_jks():
                    sync_jks()
            except ConnectionError as exc:
                logger.warn("unable to connect to KV storage; reason={}".format(exc))
            except Exception as exc:
                logger.warn("got unhandled error; reason={}".format(exc))

            # sane interval
            time.sleep(60)
    except KeyboardInterrupt:
        logger.warn("canceled by user; exiting ...")


if __name__ == "__main__":
    main()
