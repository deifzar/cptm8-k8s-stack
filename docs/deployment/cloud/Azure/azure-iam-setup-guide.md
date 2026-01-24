# Azure Identity and Access Management (IAM) Setup Guide for CPTM8

This guide covers how to create all necessary identities, roles, and permissions for deploying and managing the CPTM8 platform on Azure AKS using the **principle of least privilege**.

## Overview: Azure vs AWS Identity Concepts

| AWS Concept | Azure Equivalent | Description |
|-------------|------------------|-------------|
| IAM User | Entra ID User | Human identity for interactive access |
| IAM Access Keys | Service Principal Client Secret | Programmatic credentials |
| IAM Role (for services) | Managed Identity | Identity for Azure resources (no secrets) |
| IAM Role (assumable) | Service Principal | Identity for external apps/CI/CD |
| IAM Policy | Azure RBAC Role | Set of permissions |
| Policy Attachment | Role Assignment | Linking permissions to identity at a scope |

## Identity Types in Azure

### 1. Managed Identities (Recommended for Azure Resources)

**What:** Azure automatically manages credentials - no secrets to store or rotate.

**Types:**
- **System-assigned:** Tied to a specific resource, deleted when resource is deleted
- **User-assigned:** Standalone identity that can be shared across resources

**Use for:** AKS cluster, pods accessing Azure services (Key Vault, Blob Storage)

### 2. Service Principals

**What:** Application identity with client ID and secret/certificate.

**Use for:**
- CI/CD pipelines (GitHub Actions, Azure DevOps)
- Local development/deployment scripts
- External applications needing Azure access

### 3. Entra ID Users

**What:** Human identities for interactive access.

**Use for:** Developers, administrators accessing Azure Portal or CLI

---

## Phase 1: Prerequisites

### 1.1 Required Permissions

To set up IAM, you need one of these roles on the subscription:
- **Owner** - Full access including role assignments
- **User Access Administrator** + **Contributor** - Can manage access and create resources

```bash
# Check your current role assignments
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --output table
```

### 1.2 Set Variables

```bash
# Set these variables for use throughout the guide
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export RESOURCE_GROUP="cptm8-staging-rg"
export AKS_CLUSTER_NAME="cptm8-staging-aks"
export ACR_NAME="cptm8acr"
export KEY_VAULT_NAME="cptm8-staging-kv"
export LOCATION="westeurope"

# Verify
echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
```

---

## Phase 2: Create Custom RBAC Roles (Principle of Least Privilege)

Azure has many built-in roles, but for least privilege, we'll create custom roles where needed.

### 2.1 Understanding Azure RBAC Scopes

Permissions can be assigned at different levels (most restrictive to broadest):
```
Resource → Resource Group → Subscription → Management Group
```

**Best Practice:** Assign permissions at the narrowest scope possible.

### 2.2 Built-in Roles We'll Use

| Role | Description | Use Case |
|------|-------------|----------|
| `AcrPush` | Push images to ACR | CI/CD pipelines |
| `AcrPull` | Pull images from ACR | AKS cluster |
| `Azure Kubernetes Service Cluster Admin Role` | Full AKS admin | Initial setup only |
| `Azure Kubernetes Service Cluster User Role` | Get kubeconfig | Developers |
| `Azure Kubernetes Service RBAC Writer` | Deploy workloads | CI/CD deployment |
| `Key Vault Secrets User` | Read secrets | AKS pods |
| `Storage Blob Data Contributor` | Read/write blobs | Report storage |

### 2.3 Create Custom Role: CPTM8 Developer

This role allows developers to manage AKS workloads and view resources without full admin access.

```bash
# Create custom role definition
cat > /tmp/cptm8-developer-role.json << 'EOF'
{
  "Name": "CPTM8 Developer",
  "Description": "Can deploy and manage CPTM8 workloads on AKS with limited admin access",
  "Actions": [
    "Microsoft.ContainerService/managedClusters/read",
    "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action",
    "Microsoft.ContainerRegistry/registries/read",
    "Microsoft.ContainerRegistry/registries/pull/read",
    "Microsoft.ContainerRegistry/registries/push/write",
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.KeyVault/vaults/read",
    "Microsoft.KeyVault/vaults/secrets/read",
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/read"
  ],
  "NotActions": [],
  "DataActions": [
    "Microsoft.KeyVault/vaults/secrets/getSecret/action",
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
  ]
}
EOF

# Substitute variables
envsubst < /tmp/cptm8-developer-role.json > /tmp/cptm8-developer-role-final.json

# Create the custom role
az role definition create --role-definition /tmp/cptm8-developer-role-final.json
```

### 2.4 Create Custom Role: CPTM8 CI/CD Pipeline

Permissions for AKS deployment and ACR build operations.

> **Note:** ACR data-plane operations (push/pull) require the built-in `AcrPush` role, which must be assigned separately (see Section 3.3). Custom roles with ACR DataActions require Standard or Premium SKU and may have compatibility issues.

> If Standard of Premium SKU is obtained, add the following in DataActions in the json file below and omit the steps in Section 3.3
```bash
"DataActions": [
  "Microsoft.ContainerRegistry/registries/push/write",
  "Microsoft.ContainerRegistry/registries/pull/read"
], 
```

```bash
cat > /tmp/cptm8-cicd-role.json << 'EOF'
{
  "Name": "CPTM8 CI/CD Pipeline",
  "Description": "Permissions for CI/CD pipeline to deploy CPTM8 to AKS. Note: ACR push/pull requires separate AcrPush role assignment.",
  "Actions": [
    "Microsoft.ContainerService/managedClusters/read",
    "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action",
    "Microsoft.ContainerRegistry/registries/read",
    "Microsoft.ContainerRegistry/registries/scheduleRun/action",
    "Microsoft.ContainerRegistry/registries/runs/read",
    "Microsoft.ContainerRegistry/registries/runs/listLogSasUrl/action",
    "Microsoft.Resources/subscriptions/resourceGroups/read"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
  ]
}
EOF

envsubst < /tmp/cptm8-cicd-role.json > /tmp/cptm8-cicd-role-final.json
az role definition create --role-definition /tmp/cptm8-cicd-role-final.json
```

---

## Phase 3: Create Service Principals

### 3.1 Service Principal for CI/CD (GitHub Actions)

```bash
# Create service principal with the custom CI/CD role (AKS access)
SP_CICD=$(az ad sp create-for-rbac \
  --name "cptm8-github-actions-sp" \
  --role "CPTM8 CI/CD Pipeline" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}")

# Display credentials (save these securely!)
echo "$SP_CICD"

# The output looks like:
# {
#   "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "displayName": "cptm8-github-actions-sp",
#   "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# }

# Extract values for GitHub secrets
CICD_CLIENT_ID=$(echo $SP_CICD | jq -r '.appId')
CICD_CLIENT_SECRET=$(echo $SP_CICD | jq -r '.password')
CICD_TENANT_ID=$(echo $SP_CICD | jq -r '.tenant')

echo "AZURE_CLIENT_ID: $CICD_CLIENT_ID"
echo "AZURE_CLIENT_SECRET: $CICD_CLIENT_SECRET"
echo "AZURE_TENANT_ID: $CICD_TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
```

**Store in GitHub Secrets:**
1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Create these secrets:
   - `AZURE_CLIENT_ID` - The appId value
   - `AZURE_CLIENT_SECRET` - The password value
   - `AZURE_TENANT_ID` - The tenant value
   - `AZURE_SUBSCRIPTION_ID` - Your subscription ID

> **Note:** This service principal also requires the `AcrPush` role for pushing images to ACR. See Section 3.3 for the required role assignment.

**Store in GitHub Secrets:**
1. Go to your GitHub repository → Settings → Secrets and variables → Actions
2. Create a new secret named `AZURE_CREDENTIALS`
3. Paste the entire JSON output

### 3.2 Service Principal for Local Development

```bash
# Create SP for local kubectl/az access
SP_DEV=$(az ad sp create-for-rbac \
  --name "cptm8-local-dev-sp" \
  --role "CPTM8 Developer" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}")

echo "$SP_DEV"

# Save the credentials for local use
# You can use these with: az login --service-principal -u <appId> -p <password> --tenant <tenant>
```

### 3.3 Grant ACR Access to Service Principals (Required)

> **Important:** The custom CPTM8 CI/CD Pipeline role handles AKS deployment permissions, but ACR push/pull operations require the built-in `AcrPush` role. This hybrid approach is necessary because ACR DataActions in custom roles require Standard/Premium SKU and may have compatibility issues.

```bash
# Get ACR resource ID
ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)

# Grant AcrPush to CI/CD SP (REQUIRED for building and pushing images)
CICD_SP_ID=$(echo $SP_CICD | jq -r '.appId')
az role assignment create \
  --assignee $CICD_SP_ID \
  --role "AcrPush" \
  --scope $ACR_ID

# Grant AcrPull to Dev SP (for pulling images locally)
DEV_SP_ID=$(echo $SP_DEV | jq -r '.appId')
az role assignment create \
  --assignee $DEV_SP_ID \
  --role "AcrPull" \
  --scope $ACR_ID
```

**Summary of CI/CD Service Principal roles:**
| Role | Scope | Purpose |
|------|-------|---------|
| CPTM8 CI/CD Pipeline (custom) | Resource Group | AKS access, ACR build tasks |
| AcrPush (built-in) | ACR | Push and pull container images |

**Summary of Local Development Service Principal roles:**
| Role | Scope | Purpose |
|------|-------|---------|
| CPTM8 Developer (custom) | Resource Group | AKS access, KeyVault, Storage tasks |
| AcrPull (built-in) | ACR | Pull container images |

> **Note:** If developers need to build and push images locally (not just pull), also assign `AcrPush` instead of `AcrPull`:
> ```bash
> az role assignment create --assignee $DEV_SP_ID --role "AcrPush" --scope $ACR_ID
> ```

---

## Phase 4: Configure AKS Managed Identity

When you create an AKS cluster with `--enable-managed-identity`, Azure automatically creates:
1. **Cluster Identity** - Used by AKS control plane
2. **Kubelet Identity** - Used by nodes to pull images and access Azure resources

### 4.1 Verify AKS Managed Identities

```bash
# Get cluster identity
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query identity

# Get kubelet identity (used for ACR pulls)
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query identityProfile.kubeletidentity
```

### 4.2 Grant AKS Access to ACR (If Not Using --attach-acr)

```bash
# Get kubelet identity principal ID
KUBELET_IDENTITY=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query identityProfile.kubeletidentity.clientId -o tsv)

# Get ACR ID
ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)

# Grant AcrPull role
az role assignment create \
  --assignee $KUBELET_IDENTITY \
  --role "AcrPull" \
  --scope $ACR_ID

# Verify (alternative method using az aks check-acr)
az aks check-acr \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --acr $ACR_NAME
```

---

## Phase 5: Workload Identity for Pods (Recommended)

Workload Identity allows individual pods to have their own Azure identity, following the principle of least privilege at the pod level.

### 5.1 Enable Workload Identity on AKS

```bash
# Enable OIDC issuer and workload identity
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get the OIDC issuer URL
OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query oidcIssuerProfile.issuerUrl -o tsv)

echo "OIDC Issuer: $OIDC_ISSUER"
```

### 5.2 Create User-Assigned Managed Identity for ReportingM8

ReportingM8 needs access to Azure Blob Storage for storing reports.

```bash
# Create managed identity
az identity create \
  --name "cptm8-reportingm8-identity" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get identity client ID
REPORTING_IDENTITY_CLIENT_ID=$(az identity show \
  --name "cptm8-reportingm8-identity" \
  --resource-group $RESOURCE_GROUP \
  --query clientId -o tsv)

# Get identity principal ID
REPORTING_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name "cptm8-reportingm8-identity" \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant Storage Blob Data Contributor to the storage account 
# the 'cmptm8reports' blob storage was created in azure-staging-guide.md Phase 7 
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name cptm8reports \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

az role assignment create \
  --assignee $REPORTING_IDENTITY_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope $STORAGE_ACCOUNT_ID
```

### 5.3 Create Federated Credential

This links the Kubernetes service account to the Azure managed identity.

```bash
# Create federated credential
az identity federated-credential create \
  --name "cptm8-reportingm8-fedcred" \
  --identity-name "cptm8-reportingm8-identity" \
  --resource-group $RESOURCE_GROUP \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:cptm8-staging:reportingm8-sa" \
  --audiences "api://AzureADTokenExchange"
```

### 5.4 Create Kubernetes Service Account with Workload Identity

```yaml
# overlays/staging-azure/workload-identity/reportingm8-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: reportingm8-sa
  namespace: cptm8-staging
  annotations:
    azure.workload.identity/client-id: "${REPORTING_IDENTITY_CLIENT_ID}"
  labels:
    azure.workload.identity/use: "true"
```

```bash
# Apply the service account
envsubst < overlays/staging-azure/workload-identity/reportingm8-sa.yaml | kubectl apply -f -
```

### 5.5 Update Deployment to Use Workload Identity

```yaml
# Add to reportingm8 deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reportingm8
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"  # Required label
    spec:
      serviceAccountName: reportingm8-sa     # Use the annotated SA
      containers:
      - name: reportingm8
        # Azure SDK will automatically use workload identity
        # No secrets or environment variables needed!
```

---

## Phase 6: Key Vault Integration

### 6.1 Create Key Vault

```bash
az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization true
```
> *Note*: **If you are working from an Administrator user account, grant yourself the Key Vault Secrets Officer role:**
> 
> a. Get your user object ID
```bash
USER_ID=$(az ad signed-in-user show --query id -o tsv)
```                                     
> b. Get Key Vault resource 
```bash
KV_ID=$(az keyvault show --name $KEY_VAULT_NAME --query id -o tsv)
```                                        
> c.Assign Key Vault Secrets Officer role
```bash
az role assignment create \
    --assignee $USER_ID \
    --role "Key Vault Secrets Officer" \
    --scope $KV_ID
```

### 6.2 Add Secrets to Key Vault

```bash
# Add database passwords
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "postgresql-password" \
  --value "YourSecurePassword123!"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "mongodb-password" \
  --value "YourSecurePassword456!"

# Add other secrets...
```

### 6.3 Create Managed Identity for Secrets Access

```bash
# Create identity for pods that need secrets
az identity create \
  --name "cptm8-secrets-identity" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

SECRETS_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name "cptm8-secrets-identity" \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant Key Vault Secrets User role
az role assignment create \
  --assignee $SECRETS_IDENTITY_PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT_NAME}"
```

### 6.4 Install Secrets Store CSI Driver

```bash
# Enable the addon
az aks enable-addons \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --addons azure-keyvault-secrets-provider

# Verify installation
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
```

### 6.5 Create SecretProviderClass

```yaml
# overlays/staging-azure/secrets/secret-provider-class.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: cptm8-keyvault-secrets
  namespace: cptm8-staging
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: "${SECRETS_IDENTITY_CLIENT_ID}"  # User-assigned identity
    keyvaultName: "${KEY_VAULT_NAME}"
    tenantId: "${TENANT_ID}"
    objects: |
      array:
        - |
          objectName: postgresql-password
          objectType: secret
        - |
          objectName: mongodb-password
          objectType: secret
  secretObjects:  # Sync to Kubernetes Secret
    - secretName: database-secrets
      type: Opaque
      data:
        - objectName: postgresql-password
          key: POSTGRESQL_PASSWORD
        - objectName: mongodb-password
          key: MONGODB_PASSWORD
```

---

## Phase 7: Assign Roles to Entra ID Users/Groups

### 7.1 Create Entra ID Group for Developers

```bash
# Create group
DEVELOPER_GROUP_ID=$(az ad group create \
  --display-name "CPTM8 Developers" \
  --mail-nickname "cptm8-developers" \
  --query id -o tsv)

# Add users to group
az ad group member add \
  --group "CPTM8 Developers" \
  --member-id "<user-object-id>"
```

### 7.2 Assign Roles to Developer Group

```bash
# Grant AKS Cluster User role (can get kubeconfig)
az role assignment create \
  --assignee $DEVELOPER_GROUP_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER_NAME}"

# Grant custom CPTM8 Developer role
az role assignment create \
  --assignee $DEVELOPER_GROUP_ID \
  --role "CPTM8 Developer" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
```

### 7.3 Create Admin Group (Limited)

```bash
# Create admin group
ADMIN_GROUP_ID=$(az ad group create \
  --display-name "CPTM8 Admins" \
  --mail-nickname "cptm8-admins" \
  --query id -o tsv)

# Grant AKS Admin role (full cluster admin)
az role assignment create \
  --assignee $ADMIN_GROUP_ID \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER_NAME}"
```

---

## Phase 8: Enable AKS Azure RBAC for Kubernetes RBAC

Instead of managing Kubernetes RBAC separately, you can use Azure RBAC to control Kubernetes access.

### 8.1 Enable Azure RBAC for Kubernetes

```bash
# Update cluster to use Azure RBAC for Kubernetes authorization
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --enable-azure-rbac
```

### 8.2 Azure RBAC Roles for Kubernetes

| Azure Role | Kubernetes Equivalent | Description |
|------------|----------------------|-------------|
| Azure Kubernetes Service RBAC Reader | view | Read-only access to most objects |
| Azure Kubernetes Service RBAC Writer | edit | Read/write to most objects in namespace |
| Azure Kubernetes Service RBAC Admin | admin | Full access within namespace |
| Azure Kubernetes Service RBAC Cluster Admin | cluster-admin | Full cluster access |

### 8.3 Assign Namespace-Scoped Permissions

```bash
# Grant developers write access only to cptm8-staging namespace
az role assignment create \
  --assignee $DEVELOPER_GROUP_ID \
  --role "Azure Kubernetes Service RBAC Writer" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.ContainerService/managedClusters/${AKS_CLUSTER_NAME}/namespaces/cptm8-staging"
```

---

## Summary: Identity Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Azure Identity Architecture                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Human Access (Entra ID Users)                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐                        │
│  │  CPTM8 Admins Group │    │ CPTM8 Developers    │                        │
│  │  - AKS Cluster Admin│    │ - AKS Cluster User  │                        │
│  │  - Full access      │    │ - CPTM8 Developer   │                        │
│  └─────────────────────┘    └─────────────────────┘                        │
│                                                                              │
│  Service Principals (External Access)                                        │
│  ┌─────────────────────┐    ┌─────────────────────┐                        │
│  │ GitHub Actions SP   │    │ Local Dev SP        │                        │
│  │ - CPTM8 CI/CD Role  │    │ - CPTM8 Developer   │                        │
│  │   (AKS access)      │    │ - AcrPull           │                        │
│  │ - AcrPush (built-in)│    │                     │                        │
│  │   (ACR push/pull)   │    │                     │                        │
│  └─────────────────────┘    └─────────────────────┘                        │
│                                                                              │
│  Managed Identities (Azure Resources)                                        │
│  ┌─────────────────────┐    ┌─────────────────────┐                        │
│  │ AKS Kubelet Identity│    │ ReportingM8 Identity│                        │
│  │ - AcrPull           │    │ - Blob Contributor  │                        │
│  └─────────────────────┘    └─────────────────────┘                        │
│           │                          │                                       │
│           ▼                          ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                        AKS Cluster                                │       │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │       │
│  │  │ Pods (ACR)   │  │ ReportingM8  │  │ Other Pods   │           │       │
│  │  │ Pull images  │  │ Blob access  │  │ via CSI      │           │       │
│  │  └──────────────┘  └──────────────┘  └──────────────┘           │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Verification Checklist

```bash
# 1. Verify service principals
az ad sp list --display-name "cptm8" --output table

# 2. Verify role assignments on resource group
az role assignment list \
  --resource-group $RESOURCE_GROUP \
  --output table

# 3. Verify AKS managed identity
az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --query "{ClusterIdentity:identity, KubeletIdentity:identityProfile.kubeletidentity}"

# 4. Verify ACR access
az aks check-acr \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER_NAME \
  --acr $ACR_NAME

# 5. Test developer access (as a developer)
az login --service-principal -u <clientId> -p <clientSecret> --tenant <tenantId>
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME
kubectl get pods -n cptm8-staging

# 6. Verify Key Vault access
az keyvault secret list --vault-name $KEY_VAULT_NAME --output table
```

---

## Security Best Practices

1. **Use Managed Identities** over service principals when possible - no credentials to manage
2. **Scope permissions narrowly** - resource level > resource group > subscription
3. **Use groups** for human access - easier to manage than individual assignments
4. **Rotate service principal secrets** regularly (or use certificates)
5. **Enable Azure RBAC for Kubernetes** - unified identity management
6. **Use Workload Identity** for pod-level Azure access - no secrets in pods
7. **Audit role assignments** periodically - remove unused permissions
8. **Enable diagnostic logging** on Key Vault - track secret access

---

## Cleanup

If you need to remove all IAM resources:

```bash
# Delete service principals
az ad sp delete --id $(az ad sp list --display-name "cptm8-github-actions-sp" --query "[0].id" -o tsv)
az ad sp delete --id $(az ad sp list --display-name "cptm8-local-dev-sp" --query "[0].id" -o tsv)

# Delete managed identities
az identity delete --name "cptm8-reportingm8-identity" --resource-group $RESOURCE_GROUP
az identity delete --name "cptm8-secrets-identity" --resource-group $RESOURCE_GROUP

# Delete custom role definitions
az role definition delete --name "CPTM8 Developer"
az role definition delete --name "CPTM8 CI/CD Pipeline"

# Delete Entra ID groups
az ad group delete --group "CPTM8 Developers"
az ad group delete --group "CPTM8 Admins"
```
