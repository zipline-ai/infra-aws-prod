# Zipline AWS Infrastructure

OpenTofu infrastructure for deploying Zipline on AWS.

## Module structure

| Directory | Description |
|-----------|-------------|
| `base-aws/` | VPC, EMR cluster, DynamoDB, S3 buckets, EMR IAM roles |
| `orchestration-aws/` | EKS cluster, IRSA roles, RDS, Helm releases, ACM certs, AMP, Flink |
| `zipline-aws/` | Your deployment — wires together base-aws and orchestration-aws |
| `charts/` | Helm chart for the zipline-orchestration stack |

## Prerequisites

- [OpenTofu](https://opentofu.org/) (`tofu`) or Terraform
- AWS CLI configured with credentials that have access to your target AWS account
- A Docker Hub access token (provided by Zipline during onboarding)

## Quick start

### 1. Configure your deployment

Edit `zipline-aws/variables.tf` (or create a `terraform.tfvars` file) with your values:

```hcl
# terraform.tfvars (in zipline-aws/)
region                   = "us-west-2"
customer_name            = "your-company"
artifact_prefix          = "s3://your-zipline-artifacts"
dockerhub_token          = "<provided-by-zipline>"
```

### 2. Configure the S3 backend

Edit the `backend "s3"` block in `zipline-aws/providers.tf` to point to your own S3 bucket for storing Terraform state:

```hcl
backend "s3" {
  bucket = "your-terraform-state-bucket"
  key    = "zipline-state"
  region = "us-west-2"
}
```

### 3. Deploy

```bash
cd zipline-aws
tofu init
tofu plan
tofu apply
```

## Configuration reference

### Required variables

| Variable | Description |
|----------|-------------|
| `region` | AWS region to deploy into (e.g., `us-west-2`) |
| `customer_name` | Your unique company identifier, used as a prefix for AWS resources |
| `artifact_prefix` | S3 URI where Zipline artifacts are stored (e.g., `s3://your-zipline-artifacts`) |
| `dockerhub_token` | Docker Hub access token for pulling Zipline images (provided by Zipline) |

### Optional variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ui_domain` | `""` | Custom domain for the UI (e.g., `zipline.yourcompany.com`) |
| `hub_domain` | `""` | Custom domain for the Hub API (e.g., `zipline-hub.yourcompany.com`) |
| `hub_external_url` | `""` | Override `HUB_BASE_URL` directly (e.g., `http://my-hub-foo`). Use when a custom ALB or proxy sits in front of the hub nginx ELB and `hub_domain` is not set. |
| `fetcher_replicas` | `3` | Number of fetcher pod replicas |
| `fetcher_domain` | `""` | Custom domain for the Chronon fetcher service |
| `eval_domain` | `""` | Custom domain for the eval service |
| `databricks_client_id` | `""` | Databricks service principal client ID for Unity Catalog (optional) |
| `databricks_client_secret` | `""` | Databricks service principal client secret for Unity Catalog (optional) |

## Custom domains (HTTPS)

To expose services on your own domain with HTTPS, set the domain variables and follow these steps:

### 1. Deploy with domain variables

```bash
tofu apply \
  -var 'ui_domain=zipline.yourcompany.com' \
  -var 'hub_domain=zipline-hub.yourcompany.com' \
  -var 'fetcher_domain=zipline-fetcher.yourcompany.com' \
  -var 'eval_domain=zipline-eval.yourcompany.com'
```

This creates ACM certificates for each domain (initially in `Pending validation` state).

### 2. Add ACM validation DNS records

ACM needs to verify you own the domain. Get the validation CNAME records:

**Via AWS Console:**
1. Go to **AWS Certificate Manager** in the correct region
2. Click on the certificate (status: `Pending validation`)
3. Under **Domains**, copy the CNAME **Name** and **Value**

**Via CLI:**
```bash
aws acm list-certificates --region <your-region> \
  --query "CertificateSummaryList[?Status=='PENDING_VALIDATION']"

aws acm describe-certificate --certificate-arn <cert-arn> --region <your-region> \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord"
```

Add these CNAME records to your DNS provider. ACM will validate and issue the certificate (takes a few minutes).

### 3. Add CNAME records for traffic routing

After deployment, each service gets its own Network Load Balancer (NLB). Get the NLB hostnames:

**Via AWS Console:**
1. Go to **EC2** > **Load Balancers**
2. Each NLB's **DNS name** is shown in the Description tab

**Via CLI:**
```bash
kubectl get svc -A | grep LoadBalancer
```

Add CNAME records in your DNS provider pointing each custom domain to its NLB hostname:

| Type | Name | Target |
|------|------|--------|
| CNAME | `zipline` | `<ui-nlb-hostname>.elb.<region>.amazonaws.com` |
| CNAME | `zipline-hub` | `<hub-nlb-hostname>.elb.<region>.amazonaws.com` |
| CNAME | `zipline-fetcher` | `<fetcher-nlb-hostname>.elb.<region>.amazonaws.com` |
| CNAME | `zipline-eval` | `<eval-nlb-hostname>.elb.<region>.amazonaws.com` |

Both sets of DNS records (ACM validation and traffic routing) can be added at the same time — they are independent of each other.

## Hub URL configuration

The hub needs to know its own external URL (`HUB_BASE_URL`) to generate correct Flink UI links. There are three supported configurations:

### Option 1: Custom domain (recommended for production)

Set `hub_domain` to your custom hostname. Terraform creates an ACM certificate, configures TLS termination at the NLB, and sets `HUB_BASE_URL=https://<hub_domain>` automatically.

```hcl
hub_domain = "zipline-hub.yourcompany.com"
```

### Option 2: Custom ALB or proxy in front of the nginx ELB

If you have your own load balancer or proxy in front of the hub nginx ELB and don't want Terraform to manage a cert for it, set `hub_external_url` directly. No ACM certificate is created.

```hcl
hub_external_url = "http://my-hub-foo"
```

### Option 3: No custom domain (ELB hostname only)

If neither `hub_domain` nor `hub_external_url` is set, a Helm post-install/upgrade Job automatically looks up the hub NLB hostname and sets `HUB_BASE_URL=http://<elb-hostname>`. No extra configuration needed.

## Databricks Unity Catalog integration (optional)

To enable Databricks Unity Catalog integration, provide your service principal credentials:

```bash
tofu apply \
  -var 'databricks_client_id=<your-service-principal-uuid>' \
  -var 'databricks_client_secret=<your-service-principal-secret>'
```

This will:
- Store the credentials in AWS Secrets Manager
- Grant the orchestration IRSA role read access to the secret
- Inject `DATABRICKS_CLIENT_ID` and `DATABRICKS_CLIENT_SECRET` as environment variables into the hub pod

If these variables are left empty (the default), no Databricks resources are created and the hub runs without Unity Catalog integration.

## IAM / IRSA

Orchestration pods run under the `${customer_name}-orchestration-irsa` IAM role via IRSA (mapped to the `orchestration-sa` service account in the `zipline-system` namespace). This role has access to:

- S3: read/write on `zipline-warehouse-${customer_name}`, read-only on shared artifacts
- DynamoDB: Chronon metadata table
- EMR: job submission and cluster management
- Glue: catalog reads (`GetTable`, `GetTables`, `GetDatabase`, `GetPartitions`, etc.)
- CloudWatch Logs, AMP query
- Secrets Manager: database credentials (and Databricks credentials if configured)

## Connecting to the cluster

After deployment, configure `kubectl`:

```bash
aws eks update-kubeconfig --region <your-region> --name <customer_name>-zipline-eks
```

Verify services are running:

```bash
kubectl get pods -n zipline-system
kubectl get svc -A | grep LoadBalancer
```
