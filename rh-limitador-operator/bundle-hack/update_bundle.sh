#!/usr/bin/env bash

export LIMITADOR_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rhcl-limitador-operator@sha256:fb3b5f5267dfec9056423f5f338fdec238081ccd5ecc2da079430cfbe760dce9"

export LIMITADOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rhcl-limitador@sha256:59d9bde9c7da62665262b3f350019ab02c359d2e3db64df4a6159c7919cb3af0"

export CSV_FILE=/manifests/limitador-operator.clusterserviceversion.yaml

export DESCRIPTION=$(cat DESCRIPTION)

export ICON=$(cat ICON)

sed -i -e "s|quay.io/kuadrant/limitador-operator:.*|\"${LIMITADOR_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

sed -i -e "s|quay.io/kuadrant/limitador:.*|\"${LIMITADOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
limitador_operator_csv = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
limitador_operator_csv['metadata']['labels'] = limitador_operator_csv['metadata'].get('labels', {})
limitador_operator_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
# Ensure that the created timestamp is current
limitador_operator_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
# Add annotations for the openshift operator features
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/cnf'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/cni'] = 'false'
limitador_operator_csv['metadata']['annotations']['features.operators.openshift.io/csi'] = 'false'
limitador_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '["Red Hat Connectivity Link"]'

# Add description & icon
limitador_operator_csv['metadata']['annotations']['description'] = os.getenv('DESCRIPTION')
limitador_operator_csv['spec']['icon'][0]['base64data'] = os.getenv('ICON')

dump_manifest(os.getenv('CSV_FILE'), limitador_operator_csv)
CSV_UPDATE

cat $CSV_FILE