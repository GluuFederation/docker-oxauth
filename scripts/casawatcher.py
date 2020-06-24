import logging
import logging.config
import os
import time
from hashlib import md5

from pygluu.containerlib.utils import as_boolean
from pygluu.containerlib.meta import DockerMeta
from pygluu.containerlib.meta import KubernetesMeta

from settings import LOGGING_CONFIG

logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger("casawatcher")


class CasaWatcher(object):
    filepath_mods = {}
    casa_nums = 0

    def __init__(self):
        metadata = os.environ.get("GLUU_CONTAINER_METADATA", "docker")

        if metadata == "kubernetes":
            self.client = KubernetesMeta()
        else:
            self.client = DockerMeta()

    @property
    def rootdir(self):
        return "/etc/certs"

    @property
    def patterns(self):
        return [
            "otp_configuration.json",
            "super_gluu_creds.json",
        ]

    def sync_to_casa(self, filepaths):
        """Sync modified files to all Casa.
        """
        containers = self.client.get_containers("APP_NAME=casa")

        if not containers:
            logger.warning("Unable to find any Casa container; make sure "
                           "to deploy Casa and set APP_NAME=casa "
                           "label on container level")
            return

        for container in containers:
            for filepath in filepaths:
                logger.info("Copying {} to {}:{}".format(filepath, self.client.get_container_name(container), filepath))
                self.client.copy_to_container(container, filepath)

    def get_filepaths(self):
        filepaths = []

        for subdir, _, files in os.walk(self.rootdir):
            for file_ in files:
                filepath = os.path.join(subdir, file_)

                if os.path.basename(filepath) not in self.patterns:
                    continue
                filepaths.append(filepath)
        return filepaths

    def sync_by_digest(self, filepaths):
        _filepaths = []

        for filepath in filepaths:
            with open(filepath) as f:
                digest = md5(f.read().encode()).hexdigest()

            # skip if nothing has been tampered
            if filepath in self.filepath_mods and digest == self.filepath_mods[filepath]:
                continue

            # _filepath_mods[filepath] = digest
            _filepaths.append(filepath)
            self.filepath_mods[filepath] = digest

        # nothing changed
        if not _filepaths:
            return False

        logger.info("Sync modified files to Casa ...")
        self.sync_to_casa(_filepaths)
        return True

    def maybe_sync(self):
        try:
            casa_nums = len(self.client.get_containers("APP_NAME=casa"))
            # logger.info("Saved casa nums: " + str(self.casa_nums))
            # logger.info("Current casa nums: " + str(casa_nums))

            filepaths = self.get_filepaths()

            if self.sync_by_digest(filepaths):
                # keep the number of registered Casa for later check
                self.casa_nums = casa_nums
                return

            # check again in case we have new Casa container
            casa_nums = len(self.client.get_containers("APP_NAME=casa"))

            # probably scaled up
            if casa_nums > self.casa_nums:
                logger.info("Sync files to Casa ...")
                self.sync_to_casa(filepaths)

            # keep the number of registered Casa
            self.casa_nums = casa_nums
        except Exception as exc:
            logger.warning("Got unhandled exception; reason={}".format(exc))


def get_sync_interval():
    default_interval = 10
    try:
        sync_interval = int(os.environ.get("GLUU_CASAWATCHER_INTERVAL", default_interval))
    except ValueError:
        sync_interval = default_interval
    finally:
        if sync_interval < 1:
            sync_interval = default_interval
    return sync_interval


def main():
    enable_sync = as_boolean(
        os.environ.get("GLUU_SYNC_CASA_MANIFESTS", False)
    )
    if not enable_sync:
        logger.warning("Sync Casa files are disabled ... exiting")
        return

    try:
        sync_interval = get_sync_interval()
        watcher = CasaWatcher()

        while True:
            watcher.maybe_sync()
            time.sleep(sync_interval)
    except KeyboardInterrupt:
        logger.warning("Canceled by user ... exiting")


if __name__ == "__main__":
    main()
