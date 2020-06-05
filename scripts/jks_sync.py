import base64
import logging
import logging.config
import os
import time

from pygluu.containerlib import get_manager

from settings import LOGGING_CONFIG

manager = get_manager()

logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger("jks_sync")


def jks_created():
    # dest = manager.config.get("oxauth_openid_jks_fn")
    manager.secret.to_file("oxauth_jks_base64", "/etc/certs/oxauth-keys.jks", decode=True, binary_mode=True)
    return True


def jwks_created():
    with open("/etc/certs/oxauth-keys.json", "w") as f:
        f.write(base64.b64decode(
            manager.secret.get("oxauth_openid_key_base64")
        ))
    return True


def should_sync_jks():
    last_rotation = manager.config.get("oxauth_key_rotated_at")

    # keys are not rotated yet
    if not last_rotation:
        return False

    # check modification time of local JKS; we dont need to check JSON
    try:
        mtime = int(os.path.getmtime(manager.config.get("oxauth_openid_jks_fn")))
    except OSError:
        mtime = 0
    return mtime < int(last_rotation)


def sync_jks():
    if jks_created():
        logger.info("oxauth-keys.jks has been synchronized")
        return True
    return False


def sync_jwks():
    if jwks_created():
        logger.info("oxauth-keys.json has been synchronized")
        return True
    return False


def main():
    # delay between JKS sync (in seconds)
    sync_interval = os.environ.get("GLUU_SYNC_JKS_INTERVAL", 30)

    try:
        sync_interval = int(sync_interval)
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
                    sync_jwks()
            except Exception as exc:
                logger.warn("got unhandled error; reason={}".format(exc))

            # sane interval
            time.sleep(sync_interval)
    except KeyboardInterrupt:
        logger.warn("canceled by user; exiting ...")


if __name__ == "__main__":
    main()
