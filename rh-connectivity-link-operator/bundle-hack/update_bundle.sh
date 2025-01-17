#!/usr/bin/env bash

# enables strict mode: `-e` fails if error, `-u` checks variable references, `-o pipefail`: prevents errors in a pipeline from being masked
set -euo pipefail

#TODO: Add other component image build pullspecs once created
#export APICAST_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/apicast-gateway@sha256:de202ee9c78ae42a8a315563f8257295b4c97402dae72adad93375cdb2196ed7"
export OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/api-management-tenant/rh-connectivity-link-operator@sha256:30784d3f5d9afc8d5f62a22327796e58914b012b90d5a123d6d658db5a590646"

export CSV_FILE=/manifests/apicast-operator.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale/apicast-operator:master|\"${OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/apicast:latest|\"${APICAST_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"

# metadata/dependencies.yaml for 1.0.1, authorino-operator, limitador-operator and dns-operator dependency versions
export DEPENDENCIES_RESOURCE=/metadata/dependencies.yaml
${YQ} eval '.dependencies.[0].value.version = 0.0.0' -i $DEPENDENCIES_RESOURCE
${YQ} eval '.dependencies.[1].value.version = 0.0.0' -i $DEPENDENCIES_RESOURCE
${YQ} eval '.dependencies.[2].value.version = 0.0.0' -i $DEPENDENCIES_RESOURCE

export AMD64_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

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
csv_manifest = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
csv_manifest['metadata']['labels'] = csv_manifest['metadata'].get('labels', {})
if os.getenv('AMD64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
if os.getenv('ARM64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
if os.getenv('PPC64LE_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
if os.getenv('S390X_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
csv_manifest['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
csv_manifest['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
csv_manifest['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
# Ensure that other annotations are accurate
csv_manifest['metadata']['annotations']['repository'] = 'https://github.com/3scale/apicast-operator'
csv_manifest['metadata']['annotations']['containerImage'] = os.getenv('OPERATOR_IMAGE_PULLSPEC', '')

__dir = os.path.dirname(os.path.abspath(__file__))

# Ensure that any parameters are properly defined in the spec if you do not want to
# put them in the CSV itself
with open(f"{__dir}/DESCRIPTION", "r") as desc_file:
    description = desc_file.read()

with open(f"{__dir}/ICON", "r") as icon_file:
    icon_data = icon_file.read()

csv_manifest['spec']['description'] = description
csv_manifest['spec']['icon'][0]['base64data'] = icon_data


# Make sure that our latest nudged references are properly configured in the spec.relatedImages
# NOTE: the names should be unique
csv_manifest['spec']['relatedImages'] = [
   {'name': 'connectivity-link-operator', 'image': os.getenv('OPERATOR_IMAGE_PULLSPEC')}
]

dump_manifest(os.getenv('CSV_FILE'), csv_manifest)
CSV_UPDATE

cat $CSV_FILE