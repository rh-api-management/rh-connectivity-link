# Red Hat Connectivity Link (RHCL) Release Guide

## Introduction

This guide explains how to release Red Hat Connectivity Link (RHCL) components and file-based catalogs using Konflux. It covers the complete release process from building container images to publishing operators in OpenShift OperatorHub.

The guide is designed for team members new to Konflux and includes:

- An overview of Konflux and RHCL's architecture
- Definitions of key terminology
- Step-by-step release procedures for both components and catalogs
- Troubleshooting guidance for common issues

---

## Table of Contents

1. [What is Konflux?](#what-is-konflux)
2. [Key Terminology](#key-terminology)
3. [RHCL Application Architecture](#rhcl-application-architecture)
4. [Understanding the Release Process](#understanding-the-release-process)
5. [Prerequisites](#prerequisites)
6. [Step-by-Step: Releasing RHCL Components](#step-by-step-releasing-rhcl-components)
7. [Step-by-Step: Releasing the File-Based Catalog](#step-by-step-releasing-the-file-based-catalog)
8. [Troubleshooting](#troubleshooting)
9. [Additional Resources](#additional-resources)

---

## What is Konflux?

**Konflux** (formerly known as Red Hat Trusted Application Pipeline or RHTAP) is Red Hat's modern CI/CD platform for building, testing, and releasing containerized applications. It provides:

- **Automated Build Pipelines**: Triggered by git commits to build container images
- **Security Scanning**: Automated vulnerability scanning (Clair, Snyk, ClamAV, Coverity)
- **Enterprise Contract (EC) Validation**: Policy enforcement to ensure images meet Red Hat's release requirements
- **Release Orchestration**: Automated release pipelines that push images to registries and update catalogs

For RHCL, Konflux manages:
- Building container images for operators and supporting components
- Running security and compliance checks
- Releasing images to `registry.redhat.io` (production) and `registry.stage.redhat.io` (staging)
- Publishing file-based catalogs (FBCs) to OpenShift indexes

---

## Key Terminology

### Konflux-Specific Terms

| Term | Definition |
|------|------------|
| **Workspace (Tenant)** | An isolated environment in Konflux where applications are defined, built, and tested. RHCL uses the `api-management-tenant` workspace. |
| **Application** | A logical grouping of related components. RHCL has multiple applications (e.g., `rh-connectivity-link`, `rhcl-file-based-catalog`). |
| **Component** | A single container image built from a git repository. Examples: `rhcl-operator`, `dns-operator`, `authorino`. |
| **PipelineRun** | An execution of a Tekton pipeline. Each git push triggers a PipelineRun for building and testing. |
| **Snapshot** | A collection of component images at specific versions, representing a testable/releasable unit. |
| **Release** | The act of promoting a Snapshot to a managed namespace for distribution to customers. |
| **ReleasePlan** | A resource in the developer workspace declaring intent to release an application. |
| **ReleasePlanAdmission (RPA)** | A resource in the managed namespace (`rhtap-releng-tenant`) that defines how and where releases are executed. |

### Release-Specific Terms

| Term | Definition |
|------|------------|
| **Enterprise Contract (EC)** | A policy validation framework that checks built images against security and compliance rules before release. |
| **Enterprise Contract Policy (ECP)** | Specific policy rules that images must pass (e.g., no critical CVEs, signed builds, source containers included). |
| **File-Based Catalog (FBC)** | A declarative YAML format for defining OLM operator catalogs. RHCL uses FBC to publish operator metadata to OpenShift indexes. |
| **IIB (Index Image Builder)** | Red Hat's service for building and publishing operator index images. FBC fragments are submitted to IIB for processing. |
| **Bundle** | An OLM operator bundle containing operator manifests and metadata. Bundles are referenced in FBC fragments. |
| **Service Account** | Kubernetes service account with credentials for pushing to registries or indexes. Different accounts are used for staging vs. production. |
| **Pyxis** | Red Hat's container registry metadata service. Delivery repositories must be defined in Pyxis before releasing. |
| **Constraints** | JSON Schema validation rules that restrict what values can be used in ReleasePlanAdmissions (e.g., allowed registries, policies). |

---

## RHCL Application Architecture

RHCL uses a **version-based application structure** in Konflux, where each product version and operator has its own dedicated application. This provides clear separation between releases and allows independent versioning.

### Application Organization Pattern

Applications follow the naming convention: `rhcl-{version}-{operator-name}`

- **Version**: Product version (e.g., `1-1`, `1-2`)
- **Operator**: The specific operator (e.g., `authorino`, `dns-operator`, `limitador`, `rhcl-operator`)

### Applications in Konflux

1. rhcl-{version}-authorino
2. rhcl-{version}-dns-operator
3. rhcl-{version}-limitador
4. rhcl-{version}-rhcl-operator
5. rhcl-file-based-catalog

---

### Example: RHCL 1.1 Applications

The following structure applies to **all RHCL versions** (1.1, 1.2, etc.). Only the version number in the application/component names changes.

**Note**: All operator bundle components (production, dev, and stage) use the same source repository and branch as their corresponding operator.

#### **rhcl-1-1-authorino** (5 components)
Authorization service for RHCL 1.1

**Components:**
1. `rhcl-1-1-authorino` - Authorino container image
   - Source: `https://github.com/rh-api-management/authorino-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.authorino`

2. `rhcl-1-1-authorino-operator` - Authorino operator
   - Source: `https://github.com/rh-api-management/authorino-operator-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.authorino-operator`

3. `rhcl-1-1-authorino-operator-bundle` - Production bundle
   - Containerfile: `Containerfile.authorino-operator-bundle`

4. `rhcl-1-1-authorino-operator-bundle-dev` - Development bundle
   - Containerfile: `Containerfile.authorino-operator-bundle-dev`

5. `rhcl-1-1-authorino-operator-bundle-stage` - Staging bundle
   - Containerfile: `Containerfile.authorino-operator-bundle-stage`

#### **rhcl-1-1-dns-operator** (4 components)
DNS management operator for RHCL 1.1

**Components:**
1. `rhcl-1-1-dns-operator` - DNS operator container
   - Source: `https://github.com/rh-api-management/dns-operator-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.dns-operator`

2. `rhcl-1-1-dns-operator-bundle` - Production bundle
3. `rhcl-1-1-dns-operator-bundle-dev` - Development bundle
4. `rhcl-1-1-dns-operator-bundle-stage` - Staging bundle

#### **rhcl-1-1-limitador** (5 components)
Rate limiting service for RHCL 1.1

**Components:**
1. `rhcl-1-1-limitador` - Limitador container
   - Source: `https://github.com/rh-api-management/limitador-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.limitador`

2. `rhcl-1-1-limitador-operator` - Limitador operator
   - Source: `https://github.com/rh-api-management/limitador-operator-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.limitador-operator`

3. `rhcl-1-1-limitador-operator-bundle` - Production bundle
4. `rhcl-1-1-limitador-operator-bundle-dev` - Development bundle
5. `rhcl-1-1-limitador-operator-bundle-stage` - Staging bundle

#### **rhcl-1-1-rhcl-operator** (6 components)
Main RHCL operator for RHCL 1.1

**Components:**
1. `rhcl-1-1-rhcl-console-plugin` - OpenShift console plugin
   - Source: `https://github.com/rh-api-management/rhcl-console-plugin-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.console-plugin`

2. `rhcl-1-1-rhcl-operator` - RHCL operator
   - Source: `https://github.com/rh-api-management/rhcl-operator-product-build`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.rhcl-operator`

3. `rhcl-1-1-rhcl-operator-bundle` - Production bundle
4. `rhcl-1-1-rhcl-operator-bundle-dev` - Development bundle
5. `rhcl-1-1-rhcl-operator-bundle-stage` - Staging bundle
6. `rhcl-1-1-wasm-shim` - WebAssembly shim
   - Source: `https://github.com/rh-api-management/wasm-shim-product-build/`
   - Branch: `rhcl-1.1`
   - Containerfile: `Containerfile.wasm-shim`

---

### RHCL 1.2 and Future Versions

**The exact same structure applies to all RHCL versions.** When creating RHCL 1.2:

1. Create 4 new applications: `rhcl-1-2-authorino`, `rhcl-1-2-dns-operator`, `rhcl-1-2-limitador`, `rhcl-1-2-rhcl-operator`
2. Create version-specific branches in each repository: `rhcl-1.2`
3. Create the same components, just with `1-2` in the names instead of `1-1`

---

#### File-Based Catalog Application

##### 9. **rhcl-file-based-catalog** (8 components)
Contains FBC components for publishing operator metadata to OpenShift OperatorHub indexes.

**Components (one per OCP version):**
1. `rhcl-file-based-catalog-4-14` - OCP 4.14 catalog
2. `rhcl-file-based-catalog-4-15` - OCP 4.15 catalog
3. `rhcl-file-based-catalog-4-16` - OCP 4.16 catalog
4. `rhcl-file-based-catalog-4-17` - OCP 4.17 catalog
5. `rhcl-file-based-catalog-4-18` - OCP 4.18 catalog
6. `rhcl-file-based-catalog-4-19` - OCP 4.19 catalog
8. `rhcl-file-based-catalog-4-20` - OCP 4.20 catalog

**Source:** `https://github.com/rh-api-management/rhcl-file-based-catalog`
**Containerfiles:** `{version}.Containerfile` (e.g., `4.19.Containerfile`)

---

### Build Nudging

Components use **build-nudges-ref** to trigger dependent rebuilds:

**Example:** When `rhcl-1-2-rhcl-operator` is built, it automatically triggers builds for:
- `rhcl-1-2-rhcl-operator-bundle`
- `rhcl-1-2-rhcl-operator-bundle-stage`
- `rhcl-1-2-rhcl-operator-bundle-dev`

This ensures bundles always reference the latest operator images.

---

## Understanding the Release Process

The RHCL release process follows this high-level flow:

### 1. **Build Phase** (Developer Workspace: `api-management-tenant`)
- Developer pushes code to GitHub (`rh-api-management` repository)
- Konflux triggers PipelineRuns based on `.tekton/*.yaml` files
- Each component is built using its Containerfile
- Dependencies are prefetched using Cachi2 (Go modules, RPMs, pip packages)
- Images are built hermetically (network-isolated for reproducibility)
- Built images are pushed to `quay.io/redhat-user-workloads/api-management-tenant/`

### 2. **Test & Scan Phase**
- Enterprise Contract validation runs against built images
- Security scans execute:
  - Clair (CVE scanning)
  - Snyk (dependency analysis)
  - ClamAV (malware detection)
  - Coverity (static analysis)
  - Shell check, unicode check
- Preflight checks verify Red Hat certification requirements
- A Snapshot is created containing all tested component versions

### 3. **Release Decision**
- If ReleasePlan has `auto-release: true`, a Release is created automatically
- If `auto-release: false`, team manually creates a Release resource
- The Release references a Snapshot and a ReleasePlan

### 4. **Release Phase** (Managed Workspace: `rhtap-releng-tenant`)
- Release Service matches the ReleasePlan to a ReleasePlanAdmission (RPA)
- The RPA defines:
  - Target registries (e.g., `registry.redhat.io`)
  - Image tags
  - Enterprise Contract Policy (stricter for production)
  - Release pipeline to execute
  - Service account with credentials
- Release pipeline executes:
  - Re-validates against production EC policy
  - Signs images with Red Hat production keys
  - Pushes to `registry.redhat.io` (production) or `registry.stage.redhat.io` (staging)
  - Updates Pyxis metadata
  - For FBC: submits to IIB and publishes to operator indexes

### 5. **Post-Release**
- Customers can pull images from `registry.redhat.io`
- Operators appear in OpenShift OperatorHub catalogs
- Release artifacts are archived for compliance

---

## Prerequisites

Before releasing RHCL, ensure you have:

### Access & Permissions
1. **Konflux Access**
   - Request access: https://konflux.pages.redhat.com/docs/users/getting-started/getting-access.html
   - Workspace: `api-management-tenant`
   - Managed workspace view access: `rhtap-releng-tenant`

2. **OpenShift CLI (`oc`)**
   - Install: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html
   - Login to Konflux cluster

3. **GitLab Access**
   - Access to [`releng/konflux-release-data`](https://gitlab.cee.redhat.com/releng/konflux-release-data) repository

### Configuration Files
4. **ReleasePlanAdmissions (RPAs)**
   - Located in [`releng/konflux-release-data/config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/tree/main/config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management)
   - Files follow naming pattern: `rhcl-{version}-{component}-{environment}-rhel9.yaml`
   - Examples:
     - [`rhcl-1-2-rhcl-operator-prod-rhel9.yaml`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-1-2-rhcl-operator-prod-rhel9.yaml) (production)
     - [`rhcl-1-2-authorino-stage-rhel9.yaml`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-1-2-authorino-stage-rhel9.yaml) (staging)
     - [`rhcl-file-based-catalog-stage.yaml`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-file-based-catalog-stage.yaml) (FBC staging)
   - Example MR for creating new RPAs: [MR !10874](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/merge_requests/10874)

5. **Enterprise Contract Policies**

   RHCL uses two Enterprise Contract policies:
   - [`registry-api-management-prod`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/config/stone-prd-rh01.pg1f.p1/product/EnterpriseContractPolicy/registry-api-management-prod.yaml) - For component releases (operators, bundles, images)
   - [`fbc-standard`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/config/common/product/EnterpriseContractPolicy/fbc-standard.yaml) - For file-based catalog releases

6. **Constraints**
   - Located in: [`releng/konflux-release-data/constraints/product/api-management.yaml`](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/constraints/product/api-management.yaml)
   - Validates RPA values (registries, tags, policies)


---

## Step-by-Step: Releasing RHCL Components

This section covers releasing operator images and bundles (not FBC).

### Step 1: Verify Builds are Complete

1. **Check PipelineRuns**
   ```bash
   oc project api-management-tenant
   oc get pipelineruns --sort-by=.metadata.creationTimestamp | tail -20
   ```

2. **Find Recent Successful Builds**
   - Look for PipelineRuns with `Succeeded` status
   - Note the Snapshot name (format: `{application}-{hash}`)

3. **Inspect Snapshot**
   ```bash
   oc get snapshot {snapshot-name} -o yaml
   ```
   - Verify all expected components are present
   - Note the component image digests

4. **Verify Bundle References**

   Bundle images contain a ClusterServiceVersion (CSV) that must reference the correct operand images from the same snapshot.

   **Extract and inspect bundle manifests:**
   ```bash
   SNAPSHOT="your-snapshot-name"
   BUNDLE_IMAGE=$(kubectl get snapshot $SNAPSHOT -o yaml | yq e '.spec.components[] | select(.name | test("-operator-bundle$")).containerImage' | head -1)
   echo "Bundle image: $BUNDLE_IMAGE"

   # Extract bundle manifests to local directory
   mkdir -p ./bundle-check
   oc image extract --confirm $BUNDLE_IMAGE --path /manifests/:./bundle-check

   # Use yq to extract relatedImages
   yq e '.spec.relatedImages' ./bundle-check/*.clusterserviceversion.yaml
   ```

   **What to verify:**
   - The bundle's CSV must reference operand images that are part of the same snapshot
   - For example, `rhcl-1-1-limitador-operator-bundle` must reference the `rhcl-1-1-limitador` image digest from the snapshot
   - All image references should use digests (sha256:...), not tags
   - Image digests in the CSV should match the digests in the snapshot

   **Compare with snapshot:**
   ```bash
   # Get operand image from snapshot (for limitador example)
   # Note: This matches the limitador image, NOT the limitador-operator
   OPERAND_IMAGE=$(kubectl get snapshot $SNAPSHOT -o yaml | yq e '.spec.components[] | select(.name | test("limitador$") and (.name | test("operator") | not)).containerImage')
   echo "Operand image in snapshot: $OPERAND_IMAGE"

   # Check if this digest appears in the bundle CSV
   DIGEST=$(echo $OPERAND_IMAGE | cut -d'@' -f2)
   grep $DIGEST ./bundle-check/*.clusterserviceversion.yaml
   ```

   **Common issue**: Auto-generated snapshots may include bundles that reference outdated or unreleased operand images

   **If references are incorrect:**
   - Manually create a new snapshot including the correct component versions
   - Trigger a rebuild of the bundle component to pick up the latest nudged references

### Step 2: Choose Staging or Production

- **Staging Release**: Test the release process without affecting customers
  - Target: `registry.stage.redhat.io`
  - RPA files end with: `-stage-rhel9.yaml`
  - Example: `rhcl-1-2-rhcl-operator-stage-rhel9.yaml`

- **Production Release**: Customer-facing release
  - Target: `registry.redhat.io`
  - RPA files end with: `-prod-rhel9.yaml`
  - Example: `rhcl-1-2-rhcl-operator-prod-rhel9.yaml`

### Step 3: Update or Create ReleasePlanAdmission

**Important**: You will need to create a new RPA for each major/minor release of new components. Patch release 
can reuse existing RPAs

For existing components with updated versions:

1. **Clone the Release Data Repo**
   ```bash
   git clone git@gitlab.cee.redhat.com:releng/konflux-release-data.git
   cd konflux-release-data
   git checkout -b update-rhcl-1.2.0
   ```

2. **Edit the RPA File**
   ```bash
   vim config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-1-2-rhcl-operator-prod-rhel9.yaml
   ```

3. **Update Component Versions**
   - Locate the `mapping.components` section
   - Update `tags` for each component
   - Example:
     ```yaml
     - name: rhcl-1-2-rhcl-operator
       repository: "registry.redhat.io/rhcl-1/rhcl-rhel9-operator"
       tags:
         - "v0.2.1-{{digest_sha}}"  # New version
         - "0.2.1"
         - "rhcl-1.2.0"  # New product version tag
     ```

4. **Test Locally**
   ```bash
   tox
   ```
   - This runs validation tests, including constraint checks
   - Fix any errors before committing

5. **Commit and Push**
   ```bash
   git add config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/
   git commit -m "Update RHCL 1.2.0 production RPA"
   git push origin update-rhcl-1.2.0
   ```

6. **Create Merge Request**


7. **Merge the MR**
   - Post-merge pipeline will apply the RPA to `rhtap-releng-tenant`

### Step 4: Verify RPA is Applied

```bash
oc project rhtap-releng-tenant
oc get releaseplanadmission rhcl-1-2-rhcl-operator-prod-rhel9 -o yaml
```

- Verify the RPA matches your changes
- Check `status.conditions` for any errors

### Step 5: Create a ReleasePlan

**Important**: You need to create a new ReleasePlan for each new release.

1. **Get an Existing ReleasePlan as Template**
   ```bash
   oc get releaseplan rhcl-1-1-rhcl-operator-prod -o yaml > new-releaseplan.yaml
   ```

2. **Modify the ReleasePlan**
   - Update `metadata.name` to match your release
   - Update `metadata.labels.release.appstudio.openshift.io/releasePlanAdmission` to point to your RPA
   - Update `spec.application` to your application name
   - Update `spec.data.releaseNotes` fields (description, synopsis, topic)
   - Remove `metadata.creationTimestamp`, `metadata.generation`, `metadata.resourceVersion`, `metadata.uid`, `status` section

3. **Apply the ReleasePlan**
   ```bash
   oc apply -f new-releaseplan.yaml
   ```

4. **Verify ReleasePlan is Matched**
   ```bash
   oc get releaseplan <your-releaseplan-name> -o yaml
   ```
   Check that `status.conditions` shows `Matched: True`

### Step 6: Create a Release

1. **Get an Existing Release as Template or use embdeded example**
   ```bash
   # List recent releases to find an example
   oc get releases --sort-by=.metadata.creationTimestamp 

   # Use a specific release as template (replace with actual release name)
   oc get release rhcl-1-1-rhcl-operator-prod-20240115-123456 -o yaml > new-release.yaml
   ```
   

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: Release
metadata:
  name: rhcl-1-1-1-rhcl-operator-prod-rhel9
  namespace: api-management-tenant
spec:
  data:
    releaseNotes:
      issues:
        fixed:
          - id: CONNLINK-529
            source: issues.redhat.com
          - id: CONNLINK-433
            source: issues.redhat.com
      type: RHBA
  gracePeriodDays: 7
  releasePlan: rhcl-1-1-rhcl-operator-prod
  snapshot: rhcl-1-1-rhcl-operator-rc2
```

2. **Modify the Release**
   - Update `metadata.name` with unique timestamp
   - Update `spec.releasePlan` to your ReleasePlan name
   - Update `spec.snapshot` to your Snapshot name
   - Remove `metadata.creationTimestamp`, `metadata.generation`, `metadata.resourceVersion`, `metadata.uid`, and entire `status` section

3. **Apply the Release**
   ```bash
   oc apply -f new-release.yaml
   ```

4. **Monitor Release Pipeline**
   ```bash
   oc get release <your-release-name> -w
   ```

   Or view in the UI:
   - https://console.redhat.com/preview/application-pipeline/workspaces/api-management-tenant/releases

### Step 7: Monitor Release Execution

1. **Check Release Status**
   ```bash
   oc get release {release-name} -o yaml
   ```
   - Look at `status.conditions`
   - Note the `processing` and `succeeded` conditions

2. **Find Release PipelineRun (Optional)**
   ```bash
   oc project rhtap-releng-tenant
   oc get pipelineruns -l release.appstudio.openshift.io/name={release-name}
   ```

3. **View Pipeline Logs**
   ```bash
   oc logs -f {pipelinerun-pod-name}
   ```

   Or use the Konflux UI to view detailed task logs.

4. **Common Pipeline Tasks**
   - `verify-enterprise-contract`: Validates against production EC policy
   - `push-snapshot`: Pushes images to target registry
   - `sign-images`: Signs images with Red Hat keys
   - `update-pyxis`: Updates container metadata in Pyxis

### Step 7: Verify Release Success

1. **Check Pipeline Completion**
   ```bash
   oc get pipelinerun {pipelinerun-name}
   ```
   - Status should be `Succeeded`

2. **Verify Images in Registry**
   - For staging:
     ```bash
     podman pull registry.stage.redhat.io/rhcl-1/rhcl-rhel9-operator:1.2.0
     ```
   - For production:
     ```bash
     podman pull registry.redhat.io/rhcl-1/rhcl-rhel9-operator:1.2.0
     ```

3. **Check Pyxis Metadata**
   - Go to: https://pyxis.engineering.redhat.com/
   - Search for repository: `rhcl-1/rhcl-rhel9-operator`
   - Verify new tags are listed

### Step 8: Repeat for Other Components

RHCL releases multiple components together. Repeat the process for:
- Authorino operator and bundle
- DNS operator and bundle
- Limitador operator and bundle
- Supporting images (wasm-shim, console-plugin)

Each component has its own RPA file in the `api-management` directory.

---

## Step-by-Step: Releasing the File-Based Catalog

The file-based catalog (FBC) publishes operator metadata to OpenShift OperatorHub indexes.

### What is a File-Based Catalog?

A file-based catalog is a YAML file (`catalog.yaml`) that defines:
- **Packages**: Operator packages (e.g., `rhcl-operator`, `dns-operator`)
- **Channels**: Update channels (e.g., `stable`, `fast`)
- **Bundles**: References to operator bundle images
- **Deprecations**: Deprecated versions or channels


### FBC Architecture for RHCL

RHCL maintains separate FBC components for each supported OCP version:
- **OCP 4.14**: `rhcl-file-based-catalog-4-14`
- **OCP 4.15**: `rhcl-file-based-catalog-4-15`
- **OCP 4.16**: `rhcl-file-based-catalog-4-16`
- **OCP 4.17**: `rhcl-file-based-catalog-4-17`
- **OCP 4.18**: `rhcl-file-based-catalog-4-18`
- **OCP 4.19**: `rhcl-file-based-catalog-4-19`
- **OCP 4.20**: `rhcl-file-based-catalog-4-20`

Each component contains a `catalog.yaml` file in the `rhcl-file-based-catalog/` directory.

### Step 1: Update FBC Catalog YAML

**Important**: FBC catalogs must be updated for each operator across all supported OCP versions.

**Operator Support by OCP Version:**
- **OCP 4.14 - 4.15**: Only `authorino-operator`
- **OCP 4.16+**: All four operators:
  - `authorino-operator`
  - `dns-operator`
  - `limitador-operator`
  - `rhcl-operator`

The update process is identical for all operators in their respective supported versions.


**Prerequisites**: Complete component releases first (bundles must exist in registry) and install required tools: `kubectl`, `yq`, `opm`

1. **Navigate to FBC Repository**
   ```bash
   cd /path/to/rhcl-file-based-catalog
   ```

2. **Get Bundle URL from Release Snapshot**

   First, set the Release name. Release names follow the pattern: `rhcl-{version}-{component}-{environment}-rhel9`

   ```bash
   # Set the Release name for the operator you want to update
   RELEASE=rhcl-1-1-1-authorino-prod-rhel9

   # Get the snapshot from the Release
   SNAPSHOT=$(kubectl get releases ${RELEASE} -o jsonpath='{.spec.snapshot}')
   echo "Snapshot: $SNAPSHOT"

   # Extract bundle URL from snapshot
   BUNDLE=$(kubectl get snapshot $SNAPSHOT -o yaml | yq e '.spec.components[] | select(.name | test("-operator-bundle$")).containerImage' | head -1)
   echo "Bundle: $BUNDLE"
   ```

3. **Render Bundle and Update All OCP Catalogs**
   ```bash
   # Render the bundle to a temporary file
   TMPFILE=$(mktemp)
   opm render $BUNDLE -o yaml > $TMPFILE

   # Define OCP versions to update
   declare -a ocpversions=("4.16" "4.17" "4.18" "4.19" "4.20")

   # Loop through each OCP version
   for version in "${ocpversions[@]}"
   do
      echo "Updating OCP $version"

      # Add new line and append bundle definition
      echo "" >> catalog/$version/authorino-operator/catalog.yaml
      cat $TMPFILE >> catalog/$version/authorino-operator/catalog.yaml

      # Show existing bundles
      echo "Existing bundles in OCP $version:"
      yq e 'select(.schema == "olm.bundle").name' catalog/$version/authorino-operator/catalog.yaml

      # Add channel entry with "replaces" semantics
      yq eval --inplace '(select(.schema == "olm.channel" and .name == "stable").entries) += {"name": "authorino-operator.v1.2.0", "replaces": "authorino-operator.v1.1.0"}' catalog/$version/authorino-operator/catalog.yaml

      # Validate the updated catalog
      opm validate catalog/$version/authorino-operator
   done

   # Clean up
   rm $TMPFILE
   ```

4. **Repeat for Remaining Operators**

   Repeat steps 2-3 for the other three operators, adjusting:
   - Release name (e.g., `rhcl-1-1-dns-operator-prod-rhel9`)
   - Bundle component name (e.g., `rhcl-1-1-dns-operator-bundle`)
   - Catalog path (e.g., `catalog/$version/dns-operator/catalog.yaml`)
   - Version in `yq` command (e.g., `dns-operator.v1.2.0`)

5. **Commit and Push Changes**
   ```bash
   git add catalog/
   git commit -m "Update FBC catalogs for RHCL 1.2.0

   - authorino-operator: v1.2.0
   - dns-operator: v1.2.0
   - limitador-operator: v1.2.0
   - rhcl-operator: v1.2.0"
   git push origin main
   ```

### Step 2: Wait for FBC Build

1. **Monitor PipelineRuns**
   ```bash
   oc project api-management-tenant
   oc get pipelineruns -l appstudio.openshift.io/component=rhcl-file-based-catalog-4-19 --sort-by=.metadata.creationTimestamp
   ```

2. **Verify Build Success**
   - Each OCP version FBC component builds separately

### Step 3: Update FBC ReleasePlanAdmission

1. **Locate FBC RPA**
   ```bash
   cd konflux-release-data
   vim config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-file-based-catalog-stage.yaml
   ```

2. **Review FBC Configuration**
   ```yaml
   spec:
     applications: [rhcl-file-based-catalog]
     data:
       fbc:
         fromIndex: 'registry-proxy.engineering.redhat.com/rh-osbs/iib-pub-pending:{{ OCP_VERSION }}'
         targetIndex: ''  # Empty for staging; populated for production
         publishingCredentials: 'staged-index-fbc-publishing-credentials'
         allowedPackages: ["rhcl-operator", "dns-operator", "limitador-operator", "authorino-operator"]
         buildTimeoutSeconds: 1500
         requestTimeoutSeconds: 1500
   ```

3. **For Production Release**
   - Update `fromIndex` to `iib-pub` (production index):
     ```yaml
     fromIndex: 'registry-proxy.engineering.redhat.com/rh-osbs/iib-pub:{{ OCP_VERSION }}'
     ```
   - Set `targetIndex`:
     ```yaml
     targetIndex: 'quay.io/redhat/redhat----redhat-operator-index:{{ OCP_VERSION }}'
     ```
   - Update `publishingCredentials`:
     ```yaml
     publishingCredentials: 'fbc-production-publishing-credentials-redhat-prod'
     ```
   - Update `serviceAccountName`:
     ```yaml
     pipeline:
       serviceAccountName: release-index-image-prod
     ```

4. **Commit and Create MR**
   ```bash
   git add config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/
   git commit -m "Update FBC RPA for RHCL 1.2.0 production"
   git push origin update-rhcl-fbc-1.2.0
   # Create merge request in GitLab
   ```

### Step 4: Create FBC Release

**Note**: Since all OCP version catalogs are components of the same `rhcl-file-based-catalog` application, a single release covers all OCP versions.

1. **Find FBC Snapshot**
   ```bash
   oc project api-management-tenant
   oc get snapshots -l appstudio.openshift.io/application=rhcl-file-based-catalog --sort-by=.metadata.creationTimestamp
   ```

2. **Create Release**
   ```bash
   cat > rhcl-fbc-release.yaml <<EOF
   apiVersion: appstudio.redhat.com/v1alpha1
   kind: Release
   metadata:
     name: rhcl-fbc-1.2.0-$(date +%s)
     namespace: api-management-tenant
     labels:
       release.appstudio.openshift.io/author: 'your-username'
   spec:
     releasePlan: rhcl-file-based-catalog-stage  # Or production plan
     snapshot: {snapshot-name}
   EOF
   ```

3. **Apply Release**
   ```bash
   oc apply -f rhcl-fbc-release.yaml
   ```

### Step 5: Monitor FBC Release Pipeline

1. **Check Release Status**
   ```bash
   oc get release rhcl-fbc-1.2.0-* -w
   ```

2. **View Release Pipeline in Managed Namespace**
   ```bash
   oc project rhtap-releng-tenant
   oc get pipelineruns -l release.appstudio.openshift.io/name=rhcl-fbc-1.2.0-*
   ```

3. **Monitor IIB Submission**
   - The `fbc-release` pipeline submits the FBC fragment to IIB
   - IIB tasks:
     - **create-fbc-fragment**: Validates and processes catalog YAML
     - **add-to-index**: Merges fragment into existing index
     - **build-index**: Builds new index image
     - **push-index**: Publishes index to target registry


### Step 6: Verify FBC Publication

1. **Check Index Image**
   - For staging:
     ```bash
     podman pull registry-proxy.engineering.redhat.com/rh-osbs/iib-pub-pending:v4.19
     ```
   - For production:
     ```bash
     podman pull quay.io/redhat/redhat----redhat-operator-index:v4.19
     ```

2. **Inspect Index Contents and Verify Channel Entries**

   Verify that the new operator version appears in the catalog channels:

   ```bash
   # Set the operator package name and OCP version
   OPERATOR_PACKAGE="authorino-operator"  # Or dns-operator, limitador-operator, rhcl-operator
   OCP_VERSION="v4.19"

   # Render the index and save to a temporary file
   TMPFILE=$(mktemp)
   opm render registry.redhat.io/redhat/redhat-operator-index:${OCP_VERSION} -o json > $TMPFILE

   # Verify channel entries for the operator
   jq -s 'map(select(.package == "'"${OPERATOR_PACKAGE}"'" and .schema == "olm.channel")) | reduce .[] as $channel ({}; .[$channel.name] = [$channel.entries[].name])' $TMPFILE

   # Clean up
   rm $TMPFILE
   ```

   **Expected output:**
   ```json
   {
     "stable": [
       "authorino-operator.v1.0.0",
       "authorino-operator.v1.1.0",
       "authorino-operator.v1.2.0"
     ]
   }
   ```

   Verify that your new version (e.g., `v1.2.0`) appears in the channel entry list.

3. **Test in OpenShift**
   - Install OpenShift 4.19 (or target version)
   - Check OperatorHub:
     ```bash
     oc get packagemanifests | grep rhcl
     ```
   - Verify new version appears in the web console

---

### Getting Help

1. **Konflux Users Slack**
   - Channel: #konflux-users
   - Use "Ask for Support" button for tickets

2. **Konflux Release Slack**
   - Channel: #forum-konflux-release
   - For release-specific questions

3. **Konflux Releng Team**
   - Tag `@konflux-releng` in #konflux-users or MR comments
   - For RPA reviews and approvals

---

## Additional Resources

### Documentation

- **Konflux Docs**: https://konflux.pages.redhat.com/docs/
- **Release Data Repo**: https://gitlab.cee.redhat.com/releng/konflux-release-data
- **Preparing for Release**: https://konflux.pages.redhat.com/docs/users/releasing/preparing-for-release.html
- **Releasing Products**: https://konflux.pages.redhat.com/docs/users/releasing/releasing-products.html
- **Enterprise Contract Policies**: https://enterprisecontract.dev/docs/ec-policies/
- **Operator Lifecycle Manager (OLM)**: https://olm.operatorframework.io/

### Internal Resources

- **Release Engineering Workflow**: https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/docs/releng/releng_workflow.md
- **Konflux Release Data README**: https://gitlab.cee.redhat.com/releng/konflux-release-data/-/blob/main/README.md
- **RHCL GitHub Organization**: https://github.com/rh-api-management

### Key Repositories

- **rh-api-management**: https://github.com/rh-api-management (RHCL source)
- **konflux-release-data**: https://gitlab.cee.redhat.com/releng/konflux-release-data (Release config)
- **pyxis-repo-configs**: https://gitlab.cee.redhat.com/releng/pyxis-repo-configs (Registry metadata)
- **release-service-catalog**: https://github.com/konflux-ci/release-service-catalog (Release pipelines)

---

## Appendix: Quick Reference

### Common Commands

```bash
# Login to Konflux
oc login https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com

# Switch to developer workspace
oc project api-management-tenant

# View recent builds
oc get pipelineruns --sort-by=.metadata.creationTimestamp | tail -20

# Check snapshot
oc get snapshot {name} -o yaml

# Create a release
oc apply -f release.yaml

# Monitor release
oc get release {name} -w

# Switch to managed workspace
oc project rhtap-releng-tenant

# View release pipeline
oc get pipelineruns -l release.appstudio.openshift.io/name={release-name}

# Check RPA
oc get releaseplanadmission {name} -o yaml
```

### RPA File Locations

- **Production**: `config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-*-prod-rhel9.yaml`
- **Staging**: `config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-*-stage-rhel9.yaml`
- **FBC**: `config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/api-management/rhcl-file-based-catalog-*.yaml`

### Registry Mappings

| Environment | Registry | Example                                                                        |
|-------------|----------|--------------------------------------------------------------------------------|
| Development | quay.io/redhat-user-workloads/api-management-tenant/ | `quay.io/redhat-user-workloads/api-management-tenant/rhcl-operator:{revision}` |
| Staging | registry.stage.redhat.io | `registry.stage.redhat.io/rhcl-1/rhcl-rhel9-operator:1.1.0`                    |
| Production | registry.redhat.io | `registry.redhat.io/rhcl-1/rhcl-rhel9-operator:1.1.0`                          |

---