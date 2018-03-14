#! /bin/sh

## Script that executes the command you pass to it once consul is
## ready, i.e. populated.
##
## Typically used from docker-compose.yml:
##
## oxauth:
##   image: "gluufederation/oxauth:latest"
##   environment:
##     - GLUU_KV_HOST=consul
##     - GLUU_KV_PORT=8500
##     - GLUU_LDAP_URL=ldap:1389
##   depends_on:
##     - consul
##   command: ["/opt/scripts/wait-for-consul.sh", "--", "/opt/scripts/entrypoint.sh"]
##
## More context: https://docs.docker.com/compose/startup-order/
##
## Tested with:
## - bash 4.4.12
## - dash 0.5.8-2.4
##
## author: torstein@escenic.com
set -o nounset

LAST_CONSUL_VALUE_URI=${GLUU_KV_HOST-localhost}:${GLUU_KV_PORT-8500}/v1/kv/oxauth_openid_jwks_fn
MAX_WAIT=240

wait_for_consul_to_be_populated() {
  # Waiting for consul to be populated
  printf "Waiting up to %s seconds for Consul to be configured: " "${MAX_WAIT}"
  i=0
  while [ "${i}" -lt "${MAX_WAIT}" ]; do
    wget -O - "${LAST_CONSUL_VALUE_URI}" >/dev/null 2>/dev/null
    if [ $? -gt 0 ]; then
      printf "%s" "."
      sleep 1
    else
      break
    fi
    i=$((i+1))
  done
  printf "\n" ""
}

main() {
  wait_for_consul_to_be_populated
  exec "${@}"
}

main "$@"
