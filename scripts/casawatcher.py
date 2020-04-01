import logging
import logging.config
import os
import sys
import tarfile
import time
from hashlib import md5
from tempfile import TemporaryFile

import docker
from kubernetes import client, config
from kubernetes.stream import stream

from pygluu.containerlib.utils import as_boolean

from settings import LOGGING_CONFIG

logging.config.dictConfig(LOGGING_CONFIG)
logger = logging.getLogger("casawatcher")


class BaseClient(object):
    def get_casa_containers(self):
        """Gets Casa containers.
        Subclass __MUST__ implement this method.
        """
        raise NotImplementedError

    def get_container_ip(self, container):
        """Gets container's IP address.
        Subclass __MUST__ implement this method.
        """
        raise NotImplementedError

    def get_container_name(self, container):
        """Gets container's IP address.
        Subclass __MUST__ implement this method.
        """
        raise NotImplementedError

    def copy_to_container(self, container, path):
        """Gets container's IP address.
        Subclass __MUST__ implement this method.
        """
        raise NotImplementedError


class DockerClient(BaseClient):
    def __init__(self, base_url="unix://var/run/docker.sock"):
        self.client = docker.DockerClient(base_url=base_url)

    def get_casa_containers(self):
        return self.client.containers.list(filters={'label': 'APP_NAME=casa'})

    def get_container_ip(self, container):
        for _, network in container.attrs["NetworkSettings"]["Networks"].iteritems():
            return network["IPAddress"]

    def get_container_name(self, container):
        return container.name

    def copy_to_container(self, container, path):
        src = os.path.basename(path)
        dirname = os.path.dirname(path)

        os.chdir(dirname)

        with tarfile.open(src + ".tar", "w:gz") as tar:
            tar.add(src)

        with open(src + ".tar", "rb") as f:
            payload = f.read()

            # create directory first
            container.exec_run("mkdir -p {}".format(dirname))

            # copy file
            container.put_archive(os.path.dirname(path), payload)

        try:
            os.unlink(src + ".tar")
        except OSError:
            pass


class KubernetesClient(BaseClient):
    def __init__(self):
        config_loaded = False

        try:
            config.load_incluster_config()
            config_loaded = True
        except config.config_exception.ConfigException:
            logger.warn("Unable to load in-cluster configuration; trying to load from Kube config file")
            try:
                config.load_kube_config()
                config_loaded = True
            except (IOError, config.config_exception.ConfigException) as exc:
                logger.warn("Unable to load Kube config; reason={}".format(exc))

        if not config_loaded:
            logger.error("Unable to load in-cluster or Kube config")
            sys.exit(1)

        cli = client.CoreV1Api()
        cli.api_client.configuration.assert_hostname = False
        self.client = cli

    def get_casa_containers(self):
        return self.client.list_pod_for_all_namespaces(
            label_selector='APP_NAME=casa'
        ).items

    def get_container_ip(self, container):
        return container.status.pod_ip

    def get_container_name(self, container):
        return container.metadata.name

    def copy_to_container(self, container, path):
        # make sure parent directory is created first
        resp = stream(
            self.client.connect_get_namespaced_pod_exec,
            container.metadata.name,
            container.metadata.namespace,
            command=["/bin/sh", "-c", "mkdir -p {}".format(os.path.dirname(path))],
            stderr=True,
            stdin=True,
            stdout=True,
            tty=False,
        )

        # copy file implementation
        resp = stream(
            self.client.connect_get_namespaced_pod_exec,
            container.metadata.name,
            container.metadata.namespace,
            command=["tar", "xvf", "-", "-C", "/"],
            stderr=True,
            stdin=True,
            stdout=True,
            tty=False,
            _preload_content=False,
        )

        with TemporaryFile() as tar_buffer:
            with tarfile.open(fileobj=tar_buffer, mode="w") as tar:
                tar.add(path)

            tar_buffer.seek(0)
            commands = []
            commands.append(tar_buffer.read())

            while resp.is_open():
                resp.update(timeout=1)
                if resp.peek_stdout():
                    # logger.info("STDOUT: %s" % resp.read_stdout())
                    pass
                if resp.peek_stderr():
                    # logger.info("STDERR: %s" % resp.read_stderr())
                    pass
                if commands:
                    c = commands.pop(0)
                    resp.write_stdin(c)
                else:
                    break
            resp.close()


class CasaWatcher(object):
    filepath_mods = {}
    casa_nums = 0

    def __init__(self):
        metadata = os.environ.get("GLUU_CONTAINER_METADATA", "docker")

        if metadata == "kubernetes":
            self.client = KubernetesClient()
        else:
            self.client = DockerClient()

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
        containers = self.client.get_casa_containers()

        if not containers:
            logger.warn("Unable to find any Casa container; make sure "
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
                digest = md5(f.read()).hexdigest()

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
            casa_nums = len(self.client.get_casa_containers())
            # logger.info("Saved casa nums: " + str(self.casa_nums))
            # logger.info("Current casa nums: " + str(casa_nums))

            filepaths = self.get_filepaths()

            if self.sync_by_digest(filepaths):
                # keep the number of registered Casa for later check
                self.casa_nums = casa_nums
                return

            # check again in case we have new Casa container
            casa_nums = len(self.client.get_casa_containers())

            # probably scaled up
            if casa_nums > self.casa_nums:
                logger.info("Sync files to Casa ...")
                self.sync_to_casa(filepaths)

            # keep the number of registered Casa
            self.casa_nums = casa_nums
        except Exception as exc:
            logger.warn("Got unhandled exception; reason={}".format(exc))


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
        logger.warn("Sync Casa files are disabled ... exiting")
        return

    try:
        sync_interval = get_sync_interval()
        watcher = CasaWatcher()

        while True:
            watcher.maybe_sync()
            time.sleep(sync_interval)
    except KeyboardInterrupt:
        logger.warn("Canceled by user ... exiting")


if __name__ == "__main__":
    main()
