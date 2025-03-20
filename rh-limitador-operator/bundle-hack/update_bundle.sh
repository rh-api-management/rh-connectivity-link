#!/usr/bin/env bash

export LIMITADOR_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rh-limitador-operator@sha256:49cf786e6b5265b5edf34328496dc3fced9af4cdcc5d3fd94d949390a10ef1a1"

export LIMITADOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rh-limitador@sha256:f979746e7ec0914488dac5ce96eb2e66453626748af4f10a937f1cbf28eb3244"

export CSV_FILE=/manifests/limitador-operator.clusterserviceversion.yaml

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
limitador_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'
limitador_operator_csv['metadata']['annotations']['operators.openshift.io/valid-subscription'] = '[]'
dump_manifest(os.getenv('CSV_FILE'), limitador_operator_csv)
CSV_UPDATE

cat $CSV_FILE