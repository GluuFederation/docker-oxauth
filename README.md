# oxAuth

A docker image version of oxAuth.

## Versioning/Tagging

This image uses its own versioning/tagging format.

    <IMAGE-NAME>:<GLUU-SERVER-VERSION>_<INTERNAL-REV-VERSION>

For example, `gluufederation/oxauth:3.0.1_rev1.0.0` consists of:

- glufederation/oxauth as `<IMAGE_NAME>`; the actual image name
- 3.0.1 as `GLUU-SERVER-VERSION`; the Gluu Server version as setup reference
- rev1.0.0 as `<INTERNAL-REV-VERSION>`; revision made when developing the image

## Installation

Build the image:

```
docker build --rm --force-rm -t gluufederation/oxauth:latest .
```

Or get it from Docker Hub:

```
docker pull gluufederation/oxauth:latest
```

## Environment Variables

- `GLUU_KV_HOST`: hostname or IP address of Consul.
- `GLUU_KV_PORT`: port of Consul.
- `GLUU_LDAP_URL`: URL to LDAP in `host:port` format string (i.e. `192.168.100.4:1389`); multiple URLs can be used using comma-separated value (i.e. `192.168.100.1:1389,192.168.100.2:1389`).
- `GLUU_CUSTOM_OXAUTH_URL`: URL to downloadable custom oxAuth files packed using `.tar.gz` format.
- `GLUU_DEBUG_PORT`: port of remote debugging (if omitted, remote debugging will be disabled).

## Volumes

1. `/opt/gluu/jetty/oxauth/custom/pages` directory
2. `/opt/gluu/jetty/oxauth/custom/static` directory
3. `/opt/gluu/jetty/oxauth/lib/ext` directory

## Running The Container

Here's an example to run the container:

```
docker run -d \
    --name oxauth \
    -e GLUU_KV_HOST=my.consul.domain.com \
    -e GLUU_KV_PORT=8500 \
    -e GLUU_LDAP_URL=my.ldap.domain.com:1636 \
    -e GLUU_CUSTOM_OXAUTH_URL=http://my.domain.com/resources/custom-oxauth.tar.gz \
    gluufederation/oxauth
```

## Customizing oxAuth

oxAuth can be customized by providing HTML pages, static resource files (i.e. CSS), or JAR libraries.
Refer to https://gluu.org/docs/ce/3.0.1/operation/custom-loginpage/ for an example on how to customize oxAuth.

There are 2 ways to run oxAuth with custom files:

1.  Pass `GLUU_CUSTOM_OXAUTH_URL` environment variable; the container will download and extract the file into
    appropriate location before running the application.

    ```
    docker run -d \
        --name oxauth \
        -e GLUU_KV_HOST=my.consul.domain.com \
        -e GLUU_KV_PORT=8500 \
        -e GLUU_LDAP_URL=my.ldap.domain.com:1636 \
        -e GLUU_CUSTOM_OXAUTH_URL=http://my.domain.com/resources/custom-oxauth.tar.gz \
        gluufederation/oxauth
    ```

    The `.tar.gz` file must consist of following directories:

    ```
    ├── lib
    │   └── ext
    ├── pages
    └── static
    ```

2.  Map volumes from host to container.

    ```
    docker run -d \
        --name oxauth \
        -e GLUU_KV_HOST=my.consul.domain.com \
        -e GLUU_KV_PORT=8500 \
        -e GLUU_LDAP_URL=my.ldap.domain.com:1636 \
        -v /path/to/custom/pages:/opt/gluu/jetty/oxauth/custom/pages \
        -v /path/to/custom/static:/opt/gluu/jetty/oxauth/custom/static \
        -v /path/to/custom/lib/ext:/opt/gluu/jetty/oxauth/lib/ext \
        gluufederation/oxauth
    ```
