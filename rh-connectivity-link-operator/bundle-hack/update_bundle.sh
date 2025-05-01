#!/usr/bin/env bash

export CONNECTIVITY_LINK_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rh-connectivity-link-operator@sha256:71e63ca10b944fbfd170ccb659f3d600e7a748347ae20e4dc0f7261d03e5ede5"
export CSV_FILE=/manifests/kuadrant-operator.clusterserviceversion.yaml

export DESCRIPTION=$(cat DESCRIPTION)

export ICON=$(cat ICON)

sed -i -e "s|quay.io/kuadrant/kuadrant-operator:.*|\"${CONNECTIVITY_LINK_OPERATOR_IMAGE_PULLSPEC}\"|g" \
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
rhcl_operator_csv = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
rhcl_operator_csv['metadata']['labels'] = rhcl_operator_csv['metadata'].get('labels', {})
rhcl_operator_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
# Ensure that the created timestamp is current
rhcl_operator_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
# Add annotations for the openshift operator features
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/cnf'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/cni'] = 'false'
rhcl_operator_csv['metadata']['annotations']['features.operators.openshift.io/csi'] = 'false'
rhcl_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'
rhcl_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'

# Add description & icon
rhcl_operator_csv['metadata']['annotations']['description'] = os.getenv('DESCRIPTION')
rhcl_operator_csv['spec']['icon'][0]['base64data'] = os.getenv('ICON')

dump_manifest(os.getenv('CSV_FILE'), rhcl_operator_csv)
CSV_UPDATE

cat $CSV_FILE