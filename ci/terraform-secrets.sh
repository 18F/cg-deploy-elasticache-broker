#!/bin/bash

bosh interpolate \
  broker-config/bosh/varsfiles/terraform.yml \
  -l terraform-yaml/state.yml \
  > terraform-secrets/terraform.yml
