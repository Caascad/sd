#!/usr/bin/env bash
#stat "${BASH_SOURCE[0]/../share/schema.cue}"
set -euo pipefail

SD_DEBUG=${SD_DEBUG:-0}
SD_TRACE=${SD_TRACE:-0}
if [ "$SD_TRACE" -eq 1 ]; then set -x; fi

CAASCAD_ZONES_URL=https://git.corp.caascad.com/caascad/caascad-zones/raw/master/zones.json
RUN_BASE=${RUN_BASE:-/run/user}
RUN_DIR="${RUN_BASE}/$(id -u)/caascad-sd"
SHARE_DIR="${SHARE_DIR:-./src/share}"
INFRA_ZONE_NAME="${INFRA_ZONE_NAME:-infra-stg}"
CAASCAD_ZONES_LOCAL="${RUN_DIR}/zones.json"
CAASCAD_SD_LOCAL="${RUN_DIR}/sd.json"
KEY_SCHEMA_TEST="${SHARE_DIR}/key_schema_test.json"
SD_CUE_SCHEMA="${SHARE_DIR}/schema.cue"
ATTRIBUTES_DEFINITIONS_TEST="${SHARE_DIR}/attributes_definitions_test.json"
DATA_TEST="${SHARE_DIR}/data_test.json"
DYNAMODB_TABLE_NAME="service_discovery_${INFRA_ZONE_NAME}"
DYNAMODB_TABLE_NAME_TEST="service_discovery_test_${INFRA_ZONE_NAME}"
DYNAMODB_REGION="eu-west-3"
STS_ENDPOINT="aws/sts/power_user_${INFRA_ZONE_NAME}"

mkdir -p "${RUN_DIR}"

#main entry points
infra_zones () {
  get_creds
  pull_caascad_zone
}

validate () {
  get objects &>/dev/null
  cue vet "${CAASCAD_SD_LOCAL}" "${SD_CUE_SCHEMA}"
  }

get () {
  TYPE=$1
  case ${TYPE} in
    "zones")
      pull_caascad_zone
      cat "${CAASCAD_ZONES_LOCAL}"
      ;;
    "objects")
      get_creds
      pull_sd
      cat "${CAASCAD_SD_LOCAL}"
      ;;
    "infra_zone_names")
      jq -r '.| to_entries[]| select(.value.type=="infra")| .key' < "${CAASCAD_ZONES_LOCAL}"
      ;;
  esac
  }

dotest () {
  log_info "testing schema against test datas"
  INFRA_ZONE_NAME="infra-stg"
  log_info "nfra zone name is: ${INFRA_ZONE_NAME}"
  DYNAMODB_TABLE_NAME="${DYNAMODB_TABLE_NAME_TEST}"
  pull_caascad_zone
  VAULT_ADDR=$(build_vault_addr "${INFRA_ZONE_NAME}")
  log_debug "vault addr: ${VAULT_ADDR}"
  get_aksk "${STS_ENDPOINT}" "${VAULT_ADDR}"
  
  # first let's clean
  log_info "cleaning old test artefacts"
  drop_table "${DYNAMODB_TABLE_NAME}" &>/dev/null || true
  rm "${CAASCAD_SD_LOCAL}" "${CAASCAD_ZONES_LOCAL}" &>/dev/null || true
  
  # now we process the whole test
  create_table "${DYNAMODB_TABLE_NAME}"
  populate_table "${DYNAMODB_TABLE_NAME}" "${DATA_TEST}"
  list
  get objects
  get zones
  validate
  }

#helpers
_help () {
  cat <<EOF
NAME
      Helper script used to handle the sd

SYNOPSIS
      sd get zones|objects|infra_zone_names
      sd validate
      sd dotest

DESCRIPTION
      get
            get caascad zones or service discovery objects

      validate
            validate the content of a table

      dotest
            provison a test table, datas and then pull table to validate datas against schema

EXAMPLES

      $ sd get objects
      $ INFRA_ZONE_NAME=infra-stg sd validate
      $ sd dotest
EOF
  }

log_info () {
  echo -e "\x1B[32m--- $*\x1B[0m" >&2
  }

log_debug () {
  if [ "${SD_DEBUG}" -eq 1 ]; then
    echo -e "\x1B[34m--- $*\x1B[0m" >&2
  fi
  }

log_error () {
  echo -e "\x1B[31m--- $*\x1B[0m" >&2
  }

get_creds () {
  pull_caascad_zone
  VAULT_ADDR=$(build_vault_addr "${INFRA_ZONE_NAME}")
  get_aksk "${STS_ENDPOINT}" "${VAULT_ADDR}"
  }

build_vault_addr () {
  INFRA_ZONE_NAME=$1
  DOMAIN_NAME=$(jq -r --arg zone "${INFRA_ZONE_NAME}" '.[$zone].domain_name' < "${CAASCAD_ZONES_LOCAL}")
  echo "https://vault.${INFRA_ZONE_NAME}.${DOMAIN_NAME}"
  }

pull_caascad_zone () {
  curl -k -s -o "${CAASCAD_ZONES_LOCAL}" "${CAASCAD_ZONES_URL}"
  }

pull_sd () {
  aws dynamodb scan --table-name "${DYNAMODB_TABLE_NAME}" > "${CAASCAD_SD_LOCAL}"
  }

get_aksk () {
  STS_ENDPOINT=$1
  VAULT_ADDR=$2
  export VAULT_ADDR
  VAULT_EVAL=$(vault token lookup || vault login -method oidc)
  log_debug "${VAULT_EVAL}"
  eval "$(vault read """${STS_ENDPOINT}""" -format=json| \
  jq -r '.data|"export AWS_ACCESS_KEY_ID=\(.access_key)\nexport AWS_SECRET_ACCESS_KEY=\(.secret_key)\nexport AWS_SESSION_TOKEN=\(.security_token)"')"
  export AWS_DEFAULT_REGION="${DYNAMODB_REGION}"
  }

create_table () {
  TABLE_NAME=$1
  log_info "creating table ${TABLE_NAME}"
  RESULT=$(aws dynamodb create-table --table-name "${TABLE_NAME}" --attribute-definitions file://"${ATTRIBUTES_DEFINITIONS_TEST}" --key-schema file://"${KEY_SCHEMA_TEST}" --billing-mode PAY_PER_REQUEST)
  log_debug "${RESULT}"
  aws dynamodb wait table-exists --table-name "${TABLE_NAME}"
}

populate_table () {
  TABLE_NAME=$1
  DATA=$2
  log_info "creating table ${TABLE_NAME}"
  log_debug "data file used is: ${DATA}"
  aws dynamodb batch-write-item --request-items file://"${DATA}" 1>/dev/null
  }

drop_table () {
  TABLE_NAME=$1
  log_info "dropping table ${TABLE_NAME}"
  aws dynamodb delete-table --table-name "${TABLE_NAME}" 1>/dev/null
  aws dynamodb wait table-not-exists --table-name "${TABLE_NAME}"
  }

# display parameters
log_debug "debug level is: ${SD_DEBUG}"
log_debug "trace level is: ${SD_TRACE}"
log_debug "caascad zones url is: ${CAASCAD_ZONES_URL}"
log_debug "local caascad zones file is: ${CAASCAD_ZONES_LOCAL}"
log_debug "local sd file is: ${CAASCAD_SD_LOCAL}"
log_debug "key schema file for test is: ${KEY_SCHEMA_TEST}"
log_debug "attributes definitions file for test is: ${KEY_SCHEMA_TEST}"
log_debug "data used for test is: ${DATA_TEST}"
log_debug "dynamodb table is: ${DYNAMODB_TABLE_NAME}"
log_debug "dynamodb table used for test is: ${DYNAMODB_TABLE_NAME_TEST}"
log_debug "dynamodb region is: ${DYNAMODB_REGION}"
log_debug "vault sts endpoint is: ${STS_ENDPOINT}"

# parameters parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    help | -h | --help)
      _help
      exit 0
      ;;
    dotest|validate)
      $1
      exit 0
      ;;
    get)
      shift
      if [ "$#" -eq "0" ]; then _help; exit 1; fi
      TYPE=$1
      if [[ "${TYPE}" != "zones" && "${TYPE}" != "objects" && "${TYPE}" != "infra_zone_names" ]]; then _help; exit 1; fi
      log_info "infra zone name is: ${INFRA_ZONE_NAME}"
      get "${TYPE}"
      exit 0
      ;;
    *)
      _help
      exit 1
      ;;
  esac
done

_help
