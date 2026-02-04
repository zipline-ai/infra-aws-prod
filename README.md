# Zipline Infrastructure for AWS

This repository contains Terraform modules for deploying Zipline infrastructure on AWS.

## Architecture

| Component | AWS Service |
|-----------|-------------|
| Compute (batch) | EMR (Spark, Flink) |
| Compute (orchestration) | EKS + Helm |
| Database | RDS PostgreSQL |
| Secrets | AWS Secrets Manager |
| Storage | S3 |
| Metadata | DynamoDB |
| Identity | IRSA (IAM Roles for Service Accounts) |

## Directory Structure

```
infra-aws-prod/
├── base-aws/                    # Core infrastructure (VPC, S3, DynamoDB, EMR)
├── orchestration-aws/           # EKS + Helm orchestration
├── charts/                      # Helm charts
│   └── zipline-orchestration/   # Zipline orchestration chart
├── zipline-aws/                 # Example deployment (use this!)
├── README.md
└── LICENSE.txt
```

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Tools

```bash
# Check AWS CLI (v2 recommended)
aws --version
# Should be: aws-cli/2.x.x ...

# Check Terraform
terraform --version
# Should be: Terraform v1.x.x

# Check kubectl
kubectl version --client
# Should be: Client Version: v1.x.x

# Check Helm
helm version
# Should be: version.BuildInfo{Version:"v3.x.x", ...}
```

### AWS Configuration

```bash
# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region

# Verify your identity
aws sts get-caller-identity
# Should return your account ID, user ARN, and user ID
```

### Required AWS Permissions

Your AWS user/role needs permissions for:
- VPC, Subnets, Security Groups, Internet Gateway
- S3 bucket creation
- DynamoDB table creation
- EMR cluster creation
- EKS cluster creation
- RDS instance creation
- IAM role/policy creation
- Secrets Manager

---

## Step-by-Step Deployment Guide

### Step 1: Clone and Configure

```bash
# Navigate to the deployment directory
cd infra-aws-prod/zipline-aws

# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit the configuration file
# Use your preferred editor (vim, nano, code, etc.)
vim terraform.tfvars
```

**Required variables to set in `terraform.tfvars`:**

```hcl
# REQUIRED: Unique name for your deployment (lowercase, alphanumeric, hyphens)
customer_name = "mycompany"

# REQUIRED: AWS region
region = "us-west-2"

# REQUIRED: Docker Hub token (contact support@zipline.ai)
docker_hub_token = "dckr_pat_xxxxxxxxxxxx"

# OPTIONAL: Zipline version
zipline_version = "0.13.12"
```

### Step 2: Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init
```

**Verify success:**
```
Terraform has been successfully initialized!
```

### Step 3: Review the Plan

```bash
# Generate and review the execution plan
terraform plan -out=tfplan
```

**Verify success:**
- Review the resources to be created
- Look for `Plan: XX to add, 0 to change, 0 to destroy`
- No errors should appear

**Expected resources (~50+ resources):**
- 1 VPC, 3 subnets, security groups
- 2 S3 buckets
- 1 DynamoDB table
- 1 EMR cluster
- 1 EKS cluster with node group
- 1 RDS instance
- Multiple IAM roles and policies
- Helm releases

### Step 4: Apply the Configuration

```bash
# Apply the plan (this will take 20-40 minutes)
terraform apply tfplan
```

**Or apply directly (requires confirmation):**
```bash
terraform apply
# Type 'yes' when prompted
```

**Verify success:**
```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:

dynamodb_table = "CHRONON_METADATA_MYCOMPANY"
eks_cluster_endpoint = "https://XXXXX.gr7.us-west-2.eks.amazonaws.com"
eks_cluster_name = "zipline-mycompany-eks"
emr_cluster_id = "j-XXXXXXXXXXXXX"
emr_master_dns = "ec2-XX-XX-XX-XX.us-west-2.compute.amazonaws.com"
kubeconfig_command = "aws eks update-kubeconfig --region us-west-2 --name zipline-mycompany-eks"
logs_bucket = "zipline-logs-mycompany"
rds_endpoint = "zipline-mycompany-orchestration.xxxxx.us-west-2.rds.amazonaws.com:5432"
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
warehouse_bucket = "zipline-warehouse-mycompany"
```

---

## Verification Steps

After `terraform apply` completes, verify each component:

### 1. Verify VPC and Networking

```bash
# Get VPC ID from terraform output
VPC_ID=$(terraform output -raw vpc_id)

# Verify VPC exists
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].State'
# Expected: "available"

# Verify subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].State'
# Expected: ["available", "available", "available"]
```

### 2. Verify S3 Buckets

```bash
CUSTOMER_NAME="mycompany"  # Replace with your customer_name

# List buckets
aws s3 ls | grep zipline-.*-$CUSTOMER_NAME
# Expected:
# YYYY-MM-DD HH:MM:SS zipline-logs-mycompany
# YYYY-MM-DD HH:MM:SS zipline-warehouse-mycompany

# Verify bucket encryption
aws s3api get-bucket-encryption --bucket zipline-warehouse-$CUSTOMER_NAME
# Expected: ServerSideEncryptionConfiguration with AES256
```

### 3. Verify DynamoDB Table

```bash
CUSTOMER_NAME="mycompany"  # Replace with your customer_name

# Check table status
aws dynamodb describe-table \
  --table-name CHRONON_METADATA_$(echo $CUSTOMER_NAME | tr '[:lower:]' '[:upper:]') \
  --query 'Table.TableStatus'
# Expected: "ACTIVE"
```

### 4. Verify EMR Cluster

```bash
CUSTOMER_NAME="mycompany"  # Replace with your customer_name

# List EMR clusters
aws emr list-clusters --active --query 'Clusters[?Name==`zipline-'$CUSTOMER_NAME'-emr`]'

# Check cluster status
EMR_ID=$(terraform output -raw emr_cluster_id)
aws emr describe-cluster --cluster-id $EMR_ID --query 'Cluster.Status.State'
# Expected: "WAITING" (ready for jobs)
```

### 5. Verify EKS Cluster

```bash
# Update kubeconfig (use the command from terraform output)
aws eks update-kubeconfig --region us-west-2 --name zipline-mycompany-eks

# Verify cluster access
kubectl cluster-info
# Expected: Kubernetes control plane is running at https://...

# Check nodes are ready
kubectl get nodes
# Expected: All nodes should show STATUS: Ready

# Example output:
# NAME                                          STATUS   ROLES    AGE   VERSION
# ip-172-31-xx-xx.us-west-2.compute.internal   Ready    <none>   10m   v1.29.x
# ip-172-31-xx-xx.us-west-2.compute.internal   Ready    <none>   10m   v1.29.x
# ip-172-31-xx-xx.us-west-2.compute.internal   Ready    <none>   10m   v1.29.x
```

### 6. Verify RDS Database

```bash
CUSTOMER_NAME="mycompany"  # Replace with your customer_name

# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier zipline-$CUSTOMER_NAME-orchestration \
  --query 'DBInstances[0].DBInstanceStatus'
# Expected: "available"
```

### 7. Verify Kubernetes Workloads

```bash
# Check namespace exists
kubectl get namespace zipline-system
# Expected: STATUS: Active

# Check all pods are running
kubectl get pods -n zipline-system
# Expected: All pods should show STATUS: Running, READY: 1/1

# Example output:
# NAME                                         READY   STATUS    RESTARTS   AGE
# zipline-orchestration-hub-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
# zipline-orchestration-ui-xxxxxxxxxx-xxxxx    1/1     Running   0          5m

# Check services
kubectl get svc -n zipline-system
# Expected: orchestration-hub-service and orchestration-ui-service

# Check ingresses
kubectl get ingress -n zipline-system
# Expected: orchestration-hub-ingress and orchestration-ui-ingress with ADDRESS assigned
```

### 8. Verify Helm Release

```bash
# Check Helm release status
helm status zipline-orchestration -n zipline-system
# Expected: STATUS: deployed

# List all releases
helm list -n zipline-system
# Expected: zipline-orchestration with STATUS: deployed
```

### 9. Verify Secrets Manager

```bash
CUSTOMER_NAME="mycompany"  # Replace with your customer_name

# Check secret exists
aws secretsmanager describe-secret \
  --secret-id zipline-$CUSTOMER_NAME-db-credentials \
  --query 'Name'
# Expected: "zipline-mycompany-db-credentials"
```

### 10. Access the Application

```bash
# Get the UI ingress address
kubectl get ingress orchestration-ui-ingress -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get the Hub ingress address
kubectl get ingress orchestration-hub-ingress -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test Hub health endpoint
HUB_URL=$(kubectl get ingress orchestration-hub-ingress -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s http://$HUB_URL/ping
# Expected: Response indicating service is healthy
```

---

## Complete Verification Script

Run this script to verify all components at once:

```bash
#!/bin/bash
# save as verify-deployment.sh and run: bash verify-deployment.sh

CUSTOMER_NAME="mycompany"  # Change this to your customer_name
REGION="us-west-2"         # Change this to your region

echo "=== Zipline AWS Deployment Verification ==="
echo ""

echo "1. Checking VPC..."
VPC_ID=$(cd zipline-aws && terraform output -raw vpc_id 2>/dev/null)
if aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].State' --output text 2>/dev/null | grep -q "available"; then
  echo "   ✓ VPC is available"
else
  echo "   ✗ VPC check failed"
fi

echo ""
echo "2. Checking S3 Buckets..."
if aws s3 ls s3://zipline-warehouse-$CUSTOMER_NAME &>/dev/null; then
  echo "   ✓ Warehouse bucket exists"
else
  echo "   ✗ Warehouse bucket not found"
fi
if aws s3 ls s3://zipline-logs-$CUSTOMER_NAME &>/dev/null; then
  echo "   ✓ Logs bucket exists"
else
  echo "   ✗ Logs bucket not found"
fi

echo ""
echo "3. Checking DynamoDB..."
TABLE_NAME="CHRONON_METADATA_$(echo $CUSTOMER_NAME | tr '[:lower:]' '[:upper:]')"
if aws dynamodb describe-table --table-name $TABLE_NAME --query 'Table.TableStatus' --output text 2>/dev/null | grep -q "ACTIVE"; then
  echo "   ✓ DynamoDB table is active"
else
  echo "   ✗ DynamoDB table check failed"
fi

echo ""
echo "4. Checking EMR..."
if aws emr list-clusters --active --query "Clusters[?Name=='zipline-$CUSTOMER_NAME-emr'].Status.State" --output text 2>/dev/null | grep -q "WAITING\|RUNNING"; then
  echo "   ✓ EMR cluster is running"
else
  echo "   ✗ EMR cluster check failed"
fi

echo ""
echo "5. Checking EKS..."
aws eks update-kubeconfig --region $REGION --name zipline-$CUSTOMER_NAME-eks &>/dev/null
if kubectl get nodes &>/dev/null; then
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready" | wc -l)
  echo "   ✓ EKS cluster accessible ($READY_COUNT/$NODE_COUNT nodes ready)"
else
  echo "   ✗ EKS cluster check failed"
fi

echo ""
echo "6. Checking RDS..."
if aws rds describe-db-instances --db-instance-identifier zipline-$CUSTOMER_NAME-orchestration --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null | grep -q "available"; then
  echo "   ✓ RDS instance is available"
else
  echo "   ✗ RDS instance check failed"
fi

echo ""
echo "7. Checking Kubernetes Pods..."
PODS=$(kubectl get pods -n zipline-system --no-headers 2>/dev/null)
if [ -n "$PODS" ]; then
  TOTAL=$(echo "$PODS" | wc -l)
  RUNNING=$(echo "$PODS" | grep "Running" | wc -l)
  echo "   ✓ Pods: $RUNNING/$TOTAL running"
  echo "$PODS" | awk '{print "     - " $1 ": " $3}'
else
  echo "   ✗ No pods found in zipline-system namespace"
fi

echo ""
echo "8. Checking Helm Release..."
if helm status zipline-orchestration -n zipline-system &>/dev/null; then
  echo "   ✓ Helm release deployed"
else
  echo "   ✗ Helm release not found"
fi

echo ""
echo "9. Checking Ingress..."
HUB_URL=$(kubectl get ingress orchestration-hub-ingress -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
UI_URL=$(kubectl get ingress orchestration-ui-ingress -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$HUB_URL" ]; then
  echo "   ✓ Hub URL: http://$HUB_URL"
else
  echo "   ⚠ Hub ingress pending (may take a few minutes)"
fi
if [ -n "$UI_URL" ]; then
  echo "   ✓ UI URL: http://$UI_URL"
else
  echo "   ⚠ UI ingress pending (may take a few minutes)"
fi

echo ""
echo "=== Verification Complete ==="
```

---

## Module Reference

### base-aws

Core infrastructure module providing:

- VPC with public subnets across availability zones
- VPC endpoints for private AWS service access (S3, DynamoDB, Glue, CloudWatch, EMR, STS)
- S3 buckets for warehouse and logs
- DynamoDB table for Chronon metadata
- EMR cluster with autoscaling
- IAM roles with scoped permissions

**Key Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `customer_name` | Unique deployment identifier | required |
| `region` | AWS region | us-west-2 |
| `emr_master_instance_type` | EMR master instance type | m5.xlarge |
| `emr_core_instance_type` | EMR core instance type | m5.xlarge |
| `emr_autoscaling_max` | Max EMR instances | 10 |
| `dynamo_read_capacity` | DynamoDB RCUs | 10 |
| `dynamo_write_capacity` | DynamoDB WCUs | 10 |

### orchestration-aws

Orchestration module providing:

- EKS cluster with managed node groups
- RDS PostgreSQL for orchestration state
- AWS Secrets Manager for credentials
- IRSA (IAM Roles for Service Accounts) for secure pod-level access
- AWS Load Balancer Controller
- Secrets Store CSI Driver
- Zipline Helm release

**Key Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `eks_instance_type` | EKS node instance type | m5.2xlarge |
| `eks_desired_size` | Desired node count | 3 |
| `rds_instance_class` | RDS instance class | db.t3.medium |
| `rds_multi_az` | Enable Multi-AZ | false |
| `hub_domain` | Custom hub domain | "" |
| `ui_domain` | Custom UI domain | "" |

---

## Troubleshooting

### Terraform Apply Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check for resource name conflicts
aws s3 ls | grep zipline

# Review detailed error output
terraform apply 2>&1 | tee apply.log
```

### EKS Authentication Issues

```bash
# Verify AWS identity
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region <region> --name zipline-<customer>-eks

# Test cluster access
kubectl cluster-info

# Check if using correct context
kubectl config current-context
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n zipline-system

# Describe pod for events
kubectl describe pod -n zipline-system <pod-name>

# Check pod logs
kubectl logs -n zipline-system deployment/zipline-orchestration-hub

# Check if secrets are mounted
kubectl exec -n zipline-system deployment/zipline-orchestration-hub -- ls /mnt/secrets-store
```

### Ingress Not Getting Address

```bash
# Check ingress status
kubectl get ingress -n zipline-system

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnets have correct tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[].[SubnetId,Tags[?Key==`kubernetes.io/role/elb`].Value]'
```

### Database Connection Issues

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier zipline-<customer>-orchestration

# Check security group allows EKS access
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# Check secret exists and has correct values
aws secretsmanager get-secret-value \
  --secret-id zipline-<customer>-db-credentials \
  --query 'SecretString' --output text | jq .
```

---

## Cleanup

To destroy all resources:

```bash
cd zipline-aws

# First, check what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
# Type 'yes' when prompted
```

**Note:** RDS has deletion protection enabled. To destroy, first disable it:

```bash
aws rds modify-db-instance \
  --db-instance-identifier zipline-<customer>-orchestration \
  --no-deletion-protection \
  --apply-immediately

# Wait for modification to complete
aws rds wait db-instance-available \
  --db-instance-identifier zipline-<customer>-orchestration

# Then run terraform destroy again
terraform destroy
```

---

## Support

For support, contact support@zipline.ai

## License

Apache License 2.0 - see LICENSE.txt
