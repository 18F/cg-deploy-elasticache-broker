#!/bin/bash

set -eux

function wait_for_provision() {
  start=$(date +%s)
  until [ $(date +%s) -ge $(( ${start} + 600 )) ]; do
    status=$(cf service "${SERVICE_INSTANCE_NAME}")
    if echo ${status} | grep -iE "status:\s+create succeeded"; then
      return 0
    elif echo ${status} | grep -iE "status:\s+create failed"; then
      return 1
    fi
    sleep 60
  done
  return 1
}

function wait_for_deprovision() {
  start=$(date +%s)
  until [ $(date +%s) -ge $(( ${start} + 600 )) ]; do
    if ! cf service "${SERVICE_INSTANCE_NAME}"; then
      return 0
    fi
    sleep 60
  done
  return 1
}

INSTANCE_NAME="${SERVICE_NAME}-${PLAN_NAME}-${RANDOM}"
SERVICE_INSTANCE_NAME="${INSTANCE_NAME}"
APP_NAME="${INSTANCE_NAME}"

cf api "${CF_API_URL}"
(set +x; cf auth "${CF_USERNAME}" "${CF_PASSWORD}")

cf create-space -o "${CF_ORGANIZATION}" "${CF_SPACE}"
cf target -o "${CF_ORGANIZATION}" -s "${CF_SPACE}"

cf create-service "${SERVICE_NAME}" "${PLAN_NAME}" "${SERVICE_INSTANCE_NAME}"

pushd broker-config/ci/acceptance
  cf push --no-start "${APP_NAME}"
popd

if ! wait_for_provision; then
  echo "Failed to create service ${SERVICE_NAME}"
  exit 1
fi

cf bind-service "${APP_NAME}" "${SERVICE_INSTANCE_NAME}"
cf start "${APP_NAME}"

url=$(cf app "${APP_NAME}" | grep -e "urls: " -e "routes: " | awk '{print $2}')
status=$(curl -w "%{http_code}" "https://${url}")
if [ "${status}" != "200" ]; then
  echo "Unexpected status code ${status}"
  curl -v "https://${url}"
  cf logs "${APP_NAME}" --recent
  exit 1
fi

cf delete -f "${APP_NAME}"
cf delete-service -f "${SERVICE_INSTANCE_NAME}"

wait_for_deprovision
