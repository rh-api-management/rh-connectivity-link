#!/usr/bin/env bash

export AUTHORINO_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rh-authorino-operator@sha256:06ed578c05176306925c4d7f41962a8540c40e51ba2a4f66c311a594e58c455e"
export AUTHORINO_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rh-authorino@sha256:8b74e8630abc9aa04bceea92de8c8c62fe638871b34ba02a6fec7cbdf33f7825"

export CSV_FILE=/manifests/authorino-operator.clusterserviceversion.yaml

export DESCRIPTION=$(cat DESCRIPTION)
 
export ICON=$(cat ICON)

sed -i -e "s|quay.io/kuadrant/authorino-operator:.*|\"${AUTHORINO_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

sed -i -e "s|quay.io/kuadrant/authorino:.*|\"${AUTHORINO_IMAGE_PULLSPEC}\"|g" \
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
authorino_operator_csv = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
authorino_operator_csv['metadata']['labels'] = authorino_operator_csv['metadata'].get('labels', {})
authorino_operator_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
# Ensure that the created timestamp is current
authorino_operator_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
# Add annotations for the openshift operator features
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/cnf'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/cni'] = 'false'
authorino_operator_csv['metadata']['annotations']['features.operators.openshift.io/csi'] = 'false'
authorino_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'
authorino_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'
authorino_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '["Red Hat Connectivity Link"]'

# Add description & icon
authorino_operator_csv['metadata']['annotations']['description'] = os.getenv('DESCRIPTION')
authorino_operator_csv['spec']['icon'][0]['base64data'] = os.getenv('ICON')

dump_manifest(os.getenv('CSV_FILE'), authorino_operator_csv)
CSV_UPDATE

cat $CSV_FILE