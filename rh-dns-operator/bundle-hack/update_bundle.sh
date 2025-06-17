#!/usr/bin/env bash

export DNS_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rhcl-dns-operator@sha256:136462fc03ceafe6408084f271f57404b75d5d0f8df03780e1e17f6781c94b0b"
export CSV_FILE=/manifests/dns-operator.clusterserviceversion.yaml

export DESCRIPTION=$(cat DESCRIPTION)

export ICON=$(cat ICON)

sed -i -e "s|quay.io/kuadrant/dns-operator:.*|\"${DNS_OPERATOR_IMAGE_PULLSPEC}\"|g" \
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
dns_operator_csv = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
dns_operator_csv['metadata']['labels'] = dns_operator_csv['metadata'].get('labels', {})
dns_operator_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
# Ensure that the created timestamp is current
dns_operator_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
# Add annotations for the openshift operator features
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/cnf'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/cni'] = 'false'
dns_operator_csv['metadata']['annotations']['features.operators.openshift.io/csi'] = 'false'
dns_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '["Red Hat Connectivity Link"]'

# Add description & icon
dns_operator_csv['metadata']['annotations']['description'] = os.getenv('DESCRIPTION')
dns_operator_csv['spec']['icon'][0]['base64data'] = os.getenv('ICON')

dump_manifest(os.getenv('CSV_FILE'), dns_operator_csv)
CSV_UPDATE

cat $CSV_FILE