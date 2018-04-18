# oxAuth

A docker image version of Gluu Server oxAuth.

## Latest Stable Release

Latest stable release is `gluufederation/oxauth:3.1.2_dev`. See `CHANGES.md` for archives.

## Versioning/Tagging

This image uses its own versioning/tagging format.

    <IMAGE-NAME>:<GLUU-SERVER-VERSION>_<BASELINE_DEV>

For example, `gluufederation/oxauth:3.1.2_dev` consists of:

- glufederation/oxauth as `<IMAGE_NAME>`; the actual image name
- 3.1.2 as `GLUU-SERVER-VERSION`; the Gluu Server version as setup reference
- \_dev as `<BASELINE_DEV>`; used until official production release

## Installation

Pull the image:

```
docker pull gluufederation/oxauth:3.1.2_dev
```

## Environment Variables

- `GLUU_KV_HOST`: hostname or IP address of Consul.
- `GLUU_KV_PORT`: port of Consul.
- `GLUU_LDAP_URL`: URL to LDAP in `host:port` format string (i.e. `192.168.100.4:1636`); multiple URLs can be used using comma-separated value (i.e. `192.168.100.1:1636,192.168.100.2:1636`).
- `GLUU_CUSTOM_OXAUTH_URL`: URL to downloadable custom oxAuth files packed using `.tar.gz` format.

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
    gluufederation/oxauth:3.1.2_dev
```

## Customizing oxAuth

oxAuth can be customized by providing HTML pages, static resource files (i.e. CSS), or JAR libraries.
Refer to https://www.gluu.org/docs/ce/3.1.2/operation/custom-design/ for an example on how to customize oxAuth.

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
        gluufederation/oxauth:containership
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
        gluufederation/oxauth:containership
    ```
