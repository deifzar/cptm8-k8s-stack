# AWS IAM Setup Guide for CPTM8 Staging Environment

**Last Updated:** January 12, 2026
**Environment:** Staging (eu-south-2)
**AWS Account:** 507745009364

## 🎯 Purpose

This guide provides step-by-step instructions to create all necessary IAM users, roles, and policies for deploying and managing the CPTM8 platform on AWS EKS using the **principle of least privilege**.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Cleanup Existing Resources](#cleanup-existing-resources)
4. [IAM Roles & Policies Structure](#iam-roles--policies-structure)
5. [Step-by-Step Setup](#step-by-step-setup)
6. [Testing & Verification](#testing--verification)
7. [Security Best Practices](#security-best-practices)
8. [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

### IAM Component Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Account (507745009364)              │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  IAM User: cptm8-eks-admin                           │  │
│  │  Path: /cptm8/                                       │  │
│  │  Purpose: Human operator access                      │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │ AssumeRole (with MFA + ExternalId) │
│                       ▼                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  IAM Role: CPTM8-EKS-Cluster-Admin                   │  │
│  │  Purpose: Cluster management & operations            │  │
│  │  Policies:                                            │  │
│  │    - CPTM8-EKS-Cluster-Management                    │  │
│  │    - CPTM8-ECR-Staging-Access                        │  │
│  │    - CPTM8-VPC-Networking                            │  │
│  │    - CPTM8-Secrets-Management                        │  │
│  │    - CPTM8-S3-Access                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  IAM Role: CPTM8-EKS-Cluster-Service-Role            │  │
│  │  Principal: eks.amazonaws.com                        │  │
│  │  Purpose: EKS control plane operations               │  │
│  │  Policies:                                            │  │
│  │    - AmazonEKSClusterPolicy (AWS managed)            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  IAM Role: CPTM8-EKS-Node-Role                       │  │
│  │  Principal: ec2.amazonaws.com                        │  │
│  │  Purpose: Worker node operations                     │  │
│  │  Policies:                                            │  │
│  │    - AmazonEKSWorkerNodePolicy (AWS managed)         │  │
│  │    - AmazonEKS_CNI_Policy (AWS managed)              │  │
│  │    - AmazonEC2ContainerRegistryReadOnly (AWS)        │  │
│  │    - AmazonSSMManagedInstanceCore (AWS)              │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Access Flow

```
Developer → IAM User (cptm8-eks-admin)
          → [AssumeRole with MFA]
          → CPTM8-EKS-Cluster-Admin Role
          → EKS Cluster Management
          → Pass CPTM8-EKS-Cluster-Service-Role to EKS
          → Pass CPTM8-EKS-Node-Role to EC2 Instances
```

## 📦 Prerequisites

### Required Tools

```bash
# AWS CLI v2
aws --version  # Should be 2.x

# Configure AWS CLI with your credentials
aws configure
# AWS Access Key ID: [your key]
# AWS Secret Access Key: [your secret]
# Default region name: eu-south-2
# Default output format: json

# jq for JSON processing
sudo apt-get install jq -y

# Verify you have the correct account
aws sts get-caller-identity
# Should show Account: 507745009364
```

### Required Files Directory Structure

Create a directory for all IAM policy files:

```bash
mkdir -p ~/cptm8-iam-setup/{trust-policies,custom-policies}
cd ~/cptm8-iam-setup
```

## 🧹 Cleanup Existing Resources

If you've already created IAM resources that need to be removed, follow these steps:

### 1. List Existing Resources

```bash
# List users in /cptm8/ path
aws iam list-users --path-prefix /cptm8/

# List roles with CPTM8 prefix
aws iam list-roles | jq '.Roles[] | select(.RoleName | startswith("CPTM8"))'

# List customer managed policies with CPTM8 prefix
aws iam list-policies --scope Local | jq '.Policies[] | select(.PolicyName | startswith("CPTM8"))'
```

### 2. Detach Policies from Roles

```bash
# Detach policies from Admin Role
aws iam list-attached-role-policies --role-name CPTM8-EKS-Cluster-Admin | \
  jq -r '.AttachedPolicies[].PolicyArn' | \
  xargs -I {} aws iam detach-role-policy --role-name CPTM8-EKS-Cluster-Admin --policy-arn {}

# Detach policies from Node Role
aws iam list-attached-role-policies --role-name CPTM8-EKS-Node-Role | \
  jq -r '.AttachedPolicies[].PolicyArn' | \
  xargs -I {} aws iam detach-role-policy --role-name CPTM8-EKS-Node-Role --policy-arn {}

# Detach policies from Cluster Service Role (if exists)
aws iam list-attached-role-policies --role-name CPTM8-EKS-Cluster-Service-Role 2>/dev/null | \
  jq -r '.AttachedPolicies[].PolicyArn' | \
  xargs -I {} aws iam detach-role-policy --role-name CPTM8-EKS-Cluster-Service-Role --policy-arn {}
```

### 3. Delete Inline User Policies

```bash
# Delete inline policies from user
aws iam list-user-policies --user-name cptm8-eks-admin 2>/dev/null | \
  jq -r '.PolicyNames[]' | \
  xargs -I {} aws iam delete-user-policy --user-name cptm8-eks-admin --policy-name {}
```

### 4. Delete Roles

```bash
# Delete Admin Role
aws iam delete-role --role-name CPTM8-EKS-Cluster-Admin 2>/dev/null

# Delete Node Role
aws iam delete-role --role-name CPTM8-EKS-Node-Role 2>/dev/null

# Delete Cluster Service Role
aws iam delete-role --role-name CPTM8-EKS-Cluster-Service-Role 2>/dev/null
```

### 5. Delete Custom Policies

```bash
# Get policy ARNs and delete them
aws iam list-policies --scope Local | \
  jq -r '.Policies[] | select(.PolicyName | startswith("CPTM8")) | .Arn' | \
  xargs -I {} aws iam delete-policy --policy-arn {}
```

### 6. Delete IAM User

```bash
# Delete user (only if no dependencies remain)
aws iam delete-user --user-name cptm8-eks-admin 2>/dev/null
```

### Cleanup Verification

```bash
# Verify all resources are deleted
echo "=== Users ==="
aws iam list-users --path-prefix /cptm8/

echo "=== Roles ==="
aws iam list-roles | jq '.Roles[] | select(.RoleName | startswith("CPTM8"))'

echo "=== Policies ==="
aws iam list-policies --scope Local | jq '.Policies[] | select(.PolicyName | startswith("CPTM8"))'
```

## 🏗️ IAM Roles & Policies Structure

### Roles Summary

| Role Name                        | Purpose                                    | Principal                    | Managed By |
| -------------------------------- | ------------------------------------------ | ---------------------------- | ---------- |
| `CPTM8-EKS-Cluster-Admin`        | Human operator role for cluster management | IAM User (`cptm8-eks-admin`) | You        |
| `CPTM8-EKS-Cluster-Service-Role` | EKS control plane service role             | `eks.amazonaws.com`          | AWS EKS    |
| `CPTM8-EKS-Node-Role`            | Worker node EC2 instance role              | `ec2.amazonaws.com`          | AWS EKS    |

### Custom Policies Summary

| Policy Name                    | Purpose                               | Attached To               |
| ------------------------------ | ------------------------------------- | ------------------------- |
| `CPTM8-EKS-Cluster-Management` | EKS cluster lifecycle operations      | `CPTM8-EKS-Cluster-Admin` |
| `CPTM8-ECR-Staging-Access`     | Container registry access             | `CPTM8-EKS-Cluster-Admin` |
| `CPTM8-VPC-Networking`         | VPC and networking resources          | `CPTM8-EKS-Cluster-Admin` |
| `CPTM8-Secrets-Management`     | Secrets Manager & SSM Parameter Store | `CPTM8-EKS-Cluster-Admin` |
| `CPTM8-S3-Access`              | S3 buckets for logs, backups, reports | `CPTM8-EKS-Cluster-Admin` |

## 🔧 Step-by-Step Setup

### Step 1: Create Trust Policy Documents

#### 1.1 Admin Assume Role Trust Policy

**File:** `trust-policies/admin-assume-role-trust-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::507745009364:user/cptm8/cptm8-eks-admin"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "cptm8-staging-eks"
        },
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

**Create the file:**

```bash
cat > trust-policies/admin-assume-role-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::507745009364:user/cptm8/cptm8-eks-admin"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "cptm8-staging-eks"
        },
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
EOF
```

#### 1.2 EKS Cluster Service Role Trust Policy

**File:** `trust-policies/eks-cluster-service-trust-policy.json`

```bash
cat > trust-policies/eks-cluster-service-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

#### 1.3 EKS Node Role Trust Policy

**File:** `trust-policies/eks-node-trust-policy.json`

```bash
cat > trust-policies/eks-node-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
```

### Step 2: Create Custom Policy Documents

#### 2.1 EKS Cluster Management Policy

**File:** `custom-policies/eks-cluster-management-policy.json`

```bash
cat > custom-policies/eks-cluster-management-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSClusterOperations",
      "Effect": "Allow",
      "Action": [
        "eks:CreateCluster",
        "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion",
        "eks:DeleteCluster",
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:CreateNodegroup",
        "eks:UpdateNodegroupConfig",
        "eks:UpdateNodegroupVersion",
        "eks:DeleteNodegroup",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:CreateAddon",
        "eks:UpdateAddon",
        "eks:DeleteAddon",
        "eks:DescribeAddon",
        "eks:ListAddons",
        "eks:TagResource",
        "eks:UntagResource",
        "eks:ListTagsForResource",
        "eks:AccessKubernetesApi"
      ],
      "Resource": [
        "arn:aws:eks:eu-south-2:507745009364:cluster/cptm8-staging",
        "arn:aws:eks:eu-south-2:507745009364:cluster/cptm8-staging/*",
        "arn:aws:eks:eu-south-2:507745009364:nodegroup/cptm8-staging/*/*",
        "arn:aws:eks:eu-south-2:507745009364:addon/cptm8-staging/*/*"
      ]
    },
    {
      "Sid": "EKSDescribeOperations",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeClusterVersions",
        "eks:ListClusters",
        "eks:DescribeAddonVersions",
        "eks:DescribeAddonConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Service-Role",
        "arn:aws:iam::507745009364:role/CPTM8-EKS-Node-Role",
        "arn:aws:iam::507745009364:role/eksctl-*"
      ],
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": ["eks.amazonaws.com", "ec2.amazonaws.com"]
        }
      }
    },
    {
      "Sid": "EC2InstanceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeInstanceTypeOfferings",
        "ec2:DescribeImages",
        "ec2:DescribeKeyPairs",
        "ec2:ImportKeyPair",
        "ec2:CreateKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:CreateLaunchTemplate",
        "ec2:CreateLaunchTemplateVersion",
        "ec2:DeleteLaunchTemplate",
        "ec2:RunInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "eu-south-2"
        }
      }
    },
    {
      "Sid": "AutoScalingManagement",
      "Effect": "Allow",
      "Action": [
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:CreateOrUpdateTags",
        "autoscaling:DeleteTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "eu-south-2"
        }
      }
    },
    {
      "Sid": "ELBManagement",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudFormationStackOperations",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResources",
        "cloudformation:DescribeStackResource",
        "cloudformation:GetTemplate",
        "cloudformation:ListStackResources"
      ],
      "Resource": [
        "arn:aws:cloudformation:eu-south-2:507745009364:stack/eksctl-cptm8-staging-*/*",
        "arn:aws:cloudformation:eu-south-2:507745009364:stack/*/*"
      ]
    },
    {
      "Sid": "CloudFormationListOperations",
      "Effect": "Allow",
      "Action": [
        "cloudformation:ListStacks",
        "cloudformation:ListStackResources"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:UpdateRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:TagOpenIDConnectProvider",
        "iam:UntagOpenIDConnectProvider"
      ],
      "Resource": [
        "arn:aws:iam::507745009364:role/eksctl-*",
        "arn:aws:iam::507745009364:role/CPTM8-EKS-Node-Role",
        "arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Service-Role",
        "arn:aws:iam::507745009364:oidc-provider/oidc.eks.eu-south-2.amazonaws.com/*",
        "arn:aws:iam::507745009364:oidc-provider/oidc.eks.*.amazonaws.com/*"
      ]
    },
    {
      "Sid": "EKSServiceLinkedRole",
      "Effect": "Allow",
      "Action": ["iam:CreateServiceLinkedRole"],
      "Resource": [
        "arn:aws:iam::507745009364:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
        "arn:aws:iam::507745009364:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"
      ],
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com"]
        }
      }
    },
    {
      "Sid": "EKSServiceLinkedRoleAccess",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies"
      ],
      "Resource": "arn:aws:iam::507745009364:role/aws-service-role/*"
    },
    {
      "Sid": "CloudWatchLogsManagement",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:DeleteLogGroup",
        "logs:ListTagsLogGroup",
        "logs:TagLogGroup",
        "logs:UntagLogGroup"
      ],
      "Resource": [
        "arn:aws:logs:eu-south-2:507745009364:log-group:/aws/eks/cptm8-staging/cluster:*",
        "arn:aws:logs:eu-south-2:507745009364:log-group:/aws/eks/cptm8-*"
      ]
    }
  ]
}
EOF
```

#### 2.2 ECR Access Policy

**File:** `custom-policies/ecr-access-policy.json`

```bash
cat > custom-policies/ecr-access-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRRepositoryManagement",
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:ListTagsForResource",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:PutLifecyclePolicy",
        "ecr:GetLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:PutImageScanningConfiguration",
        "ecr:PutImageTagMutability",
        "ecr:SetRepositoryPolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:DeleteRepositoryPolicy"
      ],
      "Resource": "arn:aws:ecr:eu-south-2:507745009364:repository/cptm8/*"
    },
    {
      "Sid": "ECRImageOperations",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchDeleteImage"
      ],
      "Resource": "arn:aws:ecr:eu-south-2:507745009364:repository/cptm8/*"
    },
    {
      "Sid": "ECRAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

#### 2.3 VPC Networking Policy

**File:** `custom-policies/vpc-networking-policy.json`

```bash
cat > custom-policies/vpc-networking-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VPCManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "eu-south-2"
        }
      }
    },
    {
      "Sid": "VPCReadOperations",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSecurityGroupRules",
        "ec2:DescribeRouteTables",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeNatGateways",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeTags",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeVpcAttribute"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

#### 2.4 Secrets Management Policy

**File:** `custom-policies/secrets-management-policy.json`

```bash
cat > custom-policies/secrets-management-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecretsManagerOperations",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret",
        "secretsmanager:RestoreSecret",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource",
        "secretsmanager:ListSecrets",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:PutResourcePolicy",
        "secretsmanager:DeleteResourcePolicy"
      ],
      "Resource": "arn:aws:secretsmanager:eu-south-2:507745009364:secret:cptm8/staging/*"
    },
    {
      "Sid": "SSMParameterStore",
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:DeleteParameters",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParameterHistory",
        "ssm:DescribeParameters",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource",
        "ssm:ListTagsForResource"
      ],
      "Resource": "arn:aws:ssm:eu-south-2:507745009364:parameter/cptm8/staging/*"
    },
    {
      "Sid": "KMSForSecrets",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "secretsmanager.eu-south-2.amazonaws.com",
            "ssm.eu-south-2.amazonaws.com"
          ]
        }
      }
    }
  ]
}
EOF
```

#### 2.5 S3 Access Policy

**File:** `custom-policies/s3-access-policy.json`

```bash
cat > custom-policies/s3-access-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketManagement",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketEncryption",
        "s3:PutBucketEncryption",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutLifecycleConfiguration",
        "s3:GetLifecycleConfiguration"
      ],
      "Resource": [
        "arn:aws:s3:::cptm8-staging-*",
        "arn:aws:s3:::cptm8-reports-*",
        "arn:aws:s3:::cptm8-backups-*"
      ]
    },
    {
      "Sid": "S3ObjectOperations",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:GetObjectAcl",
        "s3:DeleteObject",
        "s3:DeleteObjects",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": [
        "arn:aws:s3:::cptm8-staging-*/*",
        "arn:aws:s3:::cptm8-reports-*/*",
        "arn:aws:s3:::cptm8-backups-*/*"
      ]
    },
    {
      "Sid": "S3ListAllBuckets",
      "Effect": "Allow",
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

#### 2.6 User AssumeRole Policy

**File:** `custom-policies/user-assume-role-policy.json`

```bash
cat > custom-policies/user-assume-role-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Admin",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "cptm8-staging-eks"
        }
      }
    }
  ]
}
EOF
```

### Step 3: Create IAM Resources

Now execute the following commands in order:

#### 3.1 Create IAM User

```bash
aws iam create-user \
  --user-name cptm8-eks-admin \
  --path /cptm8/ \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8 \
    Key=ManagedBy,Value=manual

echo "✓ IAM user created: cptm8-eks-admin"
```

#### 3.2 Create EKS Cluster Service Role

```bash
aws iam create-role \
  --role-name CPTM8-EKS-Cluster-Service-Role \
  --assume-role-policy-document file://trust-policies/eks-cluster-service-trust-policy.json \
  --description "EKS cluster service role for CPTM8 staging" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8 \
    Key=ManagedBy,Value=manual

# Attach AWS managed policy
aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Service-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

echo "✓ EKS Cluster Service Role created"
```

#### 3.3 Create EKS Node Role

```bash
aws iam create-role \
  --role-name CPTM8-EKS-Node-Role \
  --assume-role-policy-document file://trust-policies/eks-node-trust-policy.json \
  --description "EKS worker node role for CPTM8 staging" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8 \
    Key=ManagedBy,Value=manual

# Attach AWS managed policies
aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Node-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

echo "✓ EKS Node Role created with 4 AWS managed policies attached"
```

#### 3.4 Create Custom Policies

```bash
# EKS Cluster Management Policy
aws iam create-policy \
  --policy-name CPTM8-EKS-Cluster-Management \
  --policy-document file://custom-policies/eks-cluster-management-policy.json \
  --description "EKS cluster lifecycle management for CPTM8 staging" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8

# ECR Access Policy
aws iam create-policy \
  --policy-name CPTM8-ECR-Staging-Access \
  --policy-document file://custom-policies/ecr-access-policy.json \
  --description "ECR repository access for CPTM8 staging" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8

# VPC Networking Policy
aws iam create-policy \
  --policy-name CPTM8-VPC-Networking \
  --policy-document file://custom-policies/vpc-networking-policy.json \
  --description "VPC and networking management for CPTM8 staging" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8

# Secrets Management Policy
aws iam create-policy \
  --policy-name CPTM8-Secrets-Management \
  --policy-document file://custom-policies/secrets-management-policy.json \
  --description "Secrets Manager and SSM Parameter Store access for CPTM8 staging" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8

# S3 Access Policy
aws iam create-policy \
  --policy-name CPTM8-S3-Access \
  --policy-document file://custom-policies/s3-access-policy.json \
  --description "S3 bucket access for CPTM8 staging logs, backups, and reports" \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8

echo "✓ All 5 custom policies created"
```

#### 3.5 Create Admin Role

```bash
aws iam create-role \
  --role-name CPTM8-EKS-Cluster-Admin \
  --assume-role-policy-document file://trust-policies/admin-assume-role-trust-policy.json \
  --description "Admin role for CPTM8 EKS cluster management in staging" \
  --max-session-duration 43200 \
  --tags \
    Key=Environment,Value=staging \
    Key=Project,Value=CPTM8 \
    Key=ManagedBy,Value=manual

echo "✓ Admin Role created (12-hour max session duration)"
```

#### 3.6 Attach Custom Policies to Admin Role

```bash
# Get account ID dynamically
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CPTM8-EKS-Cluster-Management

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CPTM8-ECR-Staging-Access

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CPTM8-VPC-Networking

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CPTM8-Secrets-Management

aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/CPTM8-S3-Access

echo "✓ All 5 custom policies attached to Admin Role"
```

#### 3.7 Grant User Permission to Assume Admin Role

```bash
aws iam put-user-policy \
  --user-name cptm8-eks-admin \
  --policy-name AssumeAdminRole \
  --policy-document file://custom-policies/user-assume-role-policy.json

echo "✓ User granted permission to assume Admin Role"
```

#### 3.8 Create Access Keys for User

```bash
# Create access key for programmatic access
aws iam create-access-key --user-name cptm8-eks-admin > cptm8-eks-admin-credentials.json

echo "✓ Access key created and saved to cptm8-eks-admin-credentials.json"
echo "⚠️  IMPORTANT: Store this file securely and delete it after configuring AWS CLI!"
```

## ✅ Testing & Verification

### 1. Verify All Resources Created

```bash
echo "=== IAM User ==="
aws iam get-user --user-name cptm8-eks-admin

echo "=== Roles ==="
aws iam get-role --role-name CPTM8-EKS-Cluster-Admin
aws iam get-role --role-name CPTM8-EKS-Cluster-Service-Role
aws iam get-role --role-name CPTM8-EKS-Node-Role

echo "=== Custom Policies ==="
aws iam list-policies --scope Local | jq '.Policies[] | select(.PolicyName | startswith("CPTM8"))'

echo "=== Admin Role Attached Policies ==="
aws iam list-attached-role-policies --role-name CPTM8-EKS-Cluster-Admin

echo "=== Node Role Attached Policies ==="
aws iam list-attached-role-policies --role-name CPTM8-EKS-Node-Role
```

### 2. Test AssumeRole (Without MFA - Will Fail as Expected)

```bash
# This should FAIL due to MFA requirement
aws sts assume-role \
  --role-arn arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Admin \
  --role-session-name test-session \
  --external-id cptm8-staging-eks

# Expected error: "MultiFactorAuthentication failed with invalid MFA one time pass code."
```

### 3. Setup MFA Device for User

```bash
# Enable virtual MFA device (use Google Authenticator, Authy, etc.)
aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name cptm8-eks-admin-mfa \
  --outfile cptm8-mfa-qr.png \
  --bootstrap-method QRCodePNG

# Scan QR code with your MFA app, then enable it:
aws iam enable-mfa-device \
  --user-name cptm8-eks-admin \
  --serial-number arn:aws:iam::507745009364:mfa/cptm8-eks-admin-mfa \
  --authentication-code-1 <CODE1> \
  --authentication-code-2 <CODE2>
```

### 4. Test AssumeRole with MFA

```bash
# Get MFA device serial number
MFA_SERIAL=$(aws iam list-mfa-devices --user-name cptm8-eks-admin --query 'MFADevices[0].SerialNumber' --output text)

# Assume role with MFA (replace <MFA_CODE> with current 6-digit code)
aws sts assume-role \
  --role-arn arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Admin \
  --role-session-name staging-admin-session \
  --external-id cptm8-staging-eks \
  --serial-number ${MFA_SERIAL} \
  --token-code <MFA_CODE> \
  --duration-seconds 43200

# If successful, you'll receive temporary credentials (AccessKeyId, SecretAccessKey, SessionToken)
```

### 5. Configure AWS CLI Profile for AssumeRole

Add this to `~/.aws/config`:

```ini
[profile cptm8-staging-admin]
role_arn = arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Admin
source_profile = cptm8-user
external_id = cptm8-staging-eks
mfa_serial = arn:aws:iam::507745009364:mfa/cptm8-eks-admin-mfa
region = eu-south-2
output = json

[profile cptm8-user]
region = eu-south-2
output = json
```

Configure credentials in `~/.aws/credentials`:

```ini
[cptm8-user]
aws_access_key_id = <from cptm8-eks-admin-credentials.json>
aws_secret_access_key = <from cptm8-eks-admin-credentials.json>
```

### 6. Test AWS CLI with Profile

```bash
# This will prompt for MFA code
aws sts get-caller-identity --profile cptm8-staging-admin

# Expected output shows assumed role ARN:
# "Arn": "arn:aws:sts::507745009364:assumed-role/CPTM8-EKS-Cluster-Admin/staging-admin-session"
```

## 🔒 Security Best Practices

### 1. Rotate Access Keys Regularly

```bash
# Create new access key
aws iam create-access-key --user-name cptm8-eks-admin

# Update ~/.aws/credentials with new key

# After testing, delete old key
aws iam delete-access-key --user-name cptm8-eks-admin --access-key-id <OLD_KEY_ID>
```

**Recommendation:** Rotate every 90 days.

### 2. Monitor AssumeRole Usage

```bash
# Check CloudTrail for AssumeRole events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --max-results 50 \
  --region eu-south-2
```

### 3. Enable CloudTrail Logging

```bash
# Create S3 bucket for CloudTrail logs
aws s3 mb s3://cptm8-staging-cloudtrail-logs --region eu-south-2

# Create bucket policy file for CloudTrail
cat > cloudtrail-bucket-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::cptm8-staging-cloudtrail-logs"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::cptm8-staging-cloudtrail-logs/AWSLogs/507745009364/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
EOF

# Apply bucket policy (required for CloudTrail to write logs)
aws s3api put-bucket-policy \
  --region eu-south-2 \
  --bucket cptm8-staging-cloudtrail-logs \
  --policy file://cloudtrail-bucket-policy.json

# Create CloudTrail
aws cloudtrail create-trail \
  --name cptm8-staging-trail \
  --s3-bucket-name cptm8-staging-cloudtrail-logs \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --region eu-south-2

# Start logging
aws cloudtrail start-logging --name cptm8-staging-trail --region eu-south-2

# Verify CloudTrail is logging
aws cloudtrail get-trail-status --name cptm8-staging-trail --region eu-south-2
```

### 4. Review IAM Access Advisor

```bash
# See last accessed services for the admin role
aws iam generate-service-last-accessed-details \
  --arn arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Admin

# Get the JobId from output, then:
aws iam get-service-last-accessed-details --job-id <JOB_ID>
```

### 5. Set Up Billing Alarms

```bash
# Create SNS topic for billing alerts
aws sns create-topic --name cptm8-billing-alerts --region us-east-1

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:507745009364:cptm8-billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region us-east-1

# Create CloudWatch alarm (requires AWS Budgets or CloudWatch billing metrics)
```

## 🔧 Troubleshooting

### Issue 1: "User is not authorized to perform: sts:AssumeRole"

**Cause:** User doesn't have permission to assume the role.

**Solution:**

```bash
# Verify user has inline policy
aws iam get-user-policy --user-name cptm8-eks-admin --policy-name AssumeAdminRole

# If missing, re-apply:
aws iam put-user-policy \
  --user-name cptm8-eks-admin \
  --policy-name AssumeAdminRole \
  --policy-document file://custom-policies/user-assume-role-policy.json
```

### Issue 2: "MultiFactorAuthentication failed"

**Cause:** MFA device not configured or wrong code.

**Solution:**

```bash
# Check MFA devices
aws iam list-mfa-devices --user-name cptm8-eks-admin

# If no devices, follow Step 3 in Testing & Verification section
```

### Issue 3: "Access Denied" when creating EKS cluster

**Cause:** Missing IAM PassRole permission or cluster service role doesn't exist.

**Solution:**

```bash
# Verify cluster service role exists
aws iam get-role --role-name CPTM8-EKS-Cluster-Service-Role

# Verify PassRole permission in admin policy
aws iam get-policy-version \
  --policy-arn arn:aws:iam::507745009364:policy/CPTM8-EKS-Cluster-Management \
  --version-id v1 | jq '.PolicyVersion.Document.Statement[] | select(.Sid == "IAMPassRole")'
```

### Issue 4: Policy attachment fails with "EntityAlreadyExists"

**Cause:** Policy or attachment already exists from previous setup.

**Solution:**

```bash
# Detach existing policy
aws iam detach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::507745009364:policy/CPTM8-EKS-Cluster-Management

# Re-attach
aws iam attach-role-policy \
  --role-name CPTM8-EKS-Cluster-Admin \
  --policy-arn arn:aws:iam::507745009364:policy/CPTM8-EKS-Cluster-Management
```

### Issue 5: "Session token has expired"

**Cause:** AssumeRole session expired (default 1 hour, max 12 hours).

**Solution:**

```bash
# Re-assume role
aws sts assume-role \
  --role-arn arn:aws:iam::507745009364:role/CPTM8-EKS-Cluster-Admin \
  --role-session-name staging-admin-session \
  --external-id cptm8-staging-eks \
  --serial-number ${MFA_SERIAL} \
  --token-code <NEW_MFA_CODE> \
  --duration-seconds 43200  # 12 hours

# Update environment variables with new credentials
```

## 📚 Next Steps

After completing this IAM setup:

1. **Create EKS Cluster:** Follow [staging-environment-guide.md](staging-environment-guide.md)
2. **Configure kubectl:** Set up kubeconfig for cluster access
3. **Deploy CPTM8 Platform:** Use Kustomize overlays for staging environment
4. **Set up CI/CD:** Configure GitHub Actions with OIDC (see [cicd-pipeline-guide.md](cicd-pipeline-guide.md))
5. **Enable Monitoring:** Deploy Prometheus, Grafana, and CloudWatch Container Insights

## 📖 References

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [EKS IAM Roles](https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [IAM Policy Simulator](https://policysim.aws.amazon.com/)

---

**Document Version:** 1.0
**Last Reviewed:** January 12, 2026
**Maintained By:** CPTM8 Platform Team
