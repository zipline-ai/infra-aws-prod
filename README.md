# Zipline AWS Infrastructure

Terraform infrastructure for deploying Zipline on AWS through HCP Terraform.

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
  bucket     = "your-terraform-state-bucket"
  key        = "zipline-state"
  region     = "us-west-2"
  encrypt    = true
  kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
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
| `environment` | `""` | Optional environment qualifier (e.g. `canary`, `prod`). When set, prepended to S3 bucket names for global-namespace disambiguation (e.g. `zipline-warehouse-canary-yourcompany`). Only needed when you run more than one environment per customer — see [Multi-environment deployments](#multi-environment-deployments). |
| `zipline_custom_domain` | `""` | Single custom domain for the Zipline stack. UI is exposed at the root, Hub at `/services/hub`, eval at `/services/eval`, fetcher at `/services/fetcher` when fetcher is deployed, and Polaris at `/services/catalog` when in-cluster compute is enabled. When set, it takes precedence over the per-service domain variables. |
| `zipline_custom_domain_cert_arn` | `""` | ARN of an existing ACM certificate for `zipline_custom_domain`. Leave empty to let Terraform create one when `zipline_custom_domain` is set. |
| `ui_domain` | `""` | Custom domain for the UI (e.g., `zipline.yourcompany.com`) |
| `hub_domain` | `""` | Custom domain for the Hub API (e.g., `zipline-hub.yourcompany.com`) |
| `hub_external_url` | `""` | Override `HUB_BASE_URL` directly (e.g., `http://my-hub-foo`). Use when a custom ALB or proxy sits in front of the hub nginx ELB and `hub_domain` is not set. |
| `fetcher_replicas` | `3` | Number of fetcher pod replicas |
| `fetcher_domain` | `""` | Custom domain for the Chronon fetcher service |
| `eval_domain` | `""` | Custom domain for the eval service |
| `ui_cert_arn` | `""` | ARN of an existing ACM certificate for the UI domain. Leave empty to let Terraform create a certificate when `ui_domain` is set. |
| `hub_cert_arn` | `""` | ARN of an existing ACM certificate for the Hub API domain. Leave empty to let Terraform create a certificate when `hub_domain` is set. |
| `fetcher_cert_arn` | `""` | ARN of an existing ACM certificate for the Chronon fetcher domain. Leave empty to let Terraform create a certificate when `fetcher_domain` is set. |
| `eval_cert_arn` | `""` | ARN of an existing ACM certificate for the eval domain. Leave empty to let Terraform create a certificate when `eval_domain` is set. |
| `databricks_client_id` | `""` | Databricks service principal client ID for Unity Catalog (optional) |
| `databricks_client_secret` | `""` | Databricks service principal client secret for Unity Catalog (optional) |
| `dynamodb_enable_ttl` | `true` | Enable TTL and GC on DynamoDB KV store tables. Set to `false` to disable data expiry and batch table cleanup (useful when prototyping with older datasets) |
| `additional_flink_s3_buckets` | `[]` | Additional S3 bucket names to grant the Flink job execution role read/write access to (e.g. external artifact stores not covered by `artifact_prefix`) |
| `additional_data_buckets` | `[]` | Additional S3 bucket names to grant the orchestration IRSA read-only access to (e.g. external data lake buckets whose Iceberg metadata the orchestration role needs to read) |
| `in_cluster_compute_enabled` | `false` | Deploy embedded Kubernetes Spark compute resources into the orchestration cluster |
| `spark_compute_namespace` | `zipline-default` | Initial Kubernetes namespace for Zipline Spark compute jobs |
| `spark_compute_image_registry` | `""` | Optional private registry prefix for mirrored Zipline Spark compute images |
| `spark_compute_image` | `null` | Optional full Spark image override for Kubernetes compute jobs |
| `encrypt_at_rest` | `true` | Enable at-rest encryption for the Zipline RDS Postgres instance |
| `encryption_kms_key_arn` | `""` | Optional customer managed KMS key ARN for at-rest encryption. Leave empty to use AWS managed service keys |
| `encryption_kms_key_arns` | `{}` | Optional customer managed KMS key ARNs keyed by region for services that need per-region keys, such as DynamoDB Global Tables replicas |

## Optional Spark compute

To run Spark jobs through the orchestration Hub on Kubernetes, enable the embedded
compute stack in `zipline-aws/terraform.tfvars`:

```hcl
in_cluster_compute_enabled   = true
spark_compute_namespace = "zipline-default"
```

This installs the Spark Kubernetes Operator, Spark history server, Loki, RBAC,
resource quota, and service accounts into the existing orchestration cluster. The
Hub receives the Kubernetes submitter settings directly, including
`K8S_NAMESPACE`, `SPARK_IMAGE`, `SPARK_SERVICE_ACCOUNT`,
`SPARK_HISTORY_SERVER_URL`, and `SPARK_EVENT_LOG_DIR`.

## Encryption at rest

By default, this deployment enables at-rest encryption for the managed data stores it creates:

- RDS Postgres storage
- Zipline warehouse and logs S3 buckets
- DynamoDB tables
- Secrets Manager entries created by the stack

If your organization requires a customer-managed KMS key, set `encryption_kms_key_arn` in `zipline-aws/terraform.tfvars`:

```hcl
encrypt_at_rest        = true
encryption_kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
```

When `encryption_kms_key_arn` is empty, AWS managed service keys are used. Make sure the KMS key policy allows the AWS services and IAM principals in this stack to use the key, including RDS, S3, DynamoDB, Secrets Manager, EKS node roles, and any operators running `tofu apply`.

### Terraform state backend encryption

Terraform/OpenTofu state encryption is configured separately from stack resource encryption. The `encryption_kms_key_arn` variable does not affect the S3 backend because backend blocks are processed during `tofu init` and cannot read values from `terraform.tfvars`.

To use a customer-managed KMS key for Terraform/OpenTofu state, set the backend's `kms_key_id` alongside `encrypt = true`:

```hcl
backend "s3" {
  bucket     = "your-terraform-state-bucket"
  key        = "zipline-state"
  region     = "us-west-2"
  encrypt    = true
  kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000"
}
```

You can also keep the backend block partial and pass the key during init:

```bash
tofu init \
  -backend-config='encrypt=true' \
  -backend-config='kms_key_id=arn:aws:kms:us-west-2:123456789012:key/00000000-0000-0000-0000-000000000000'
```

If `dynamodb_replica_regions` is set for `CHRONON_METADATA`, a single-region KMS key ARN cannot be reused in every replica region. Use one of these options:

- Set `encryption_kms_key_arn` to a multi-Region KMS key ARN.
- Provide region-specific replica keys in `encryption_kms_key_arns`.

```hcl
encryption_kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/mrk-00000000000000000000000000000000"

encryption_kms_key_arns = {
  eu-west-1 = "arn:aws:kms:eu-west-1:123456789012:key/mrk-11111111111111111111111111111111"
}
```

### Existing RDS instances

RDS storage encryption cannot be enabled in place on an existing unencrypted Postgres instance. If this stack already created an unencrypted DB, do not expect a normal `tofu apply` to encrypt it without replacement. Migrate with an encrypted snapshot instead:

1. Schedule a maintenance window.
2. Create a manual snapshot of the existing DB.
3. Copy the snapshot with encryption enabled, using either your customer managed key or the AWS managed RDS key.
4. Restore a new DB instance from the encrypted snapshot.
5. Import the new encrypted DB into Terraform state or otherwise update Terraform to manage the restored instance.
6. Cut application traffic over to the new endpoint.
7. Verify `StorageEncrypted` is `true`.
8. Retire the old unencrypted DB only after backups and application validation are complete.

Take and verify a manual snapshot before any destructive DB operation. This is especially important because deleting an RDS instance with `skip_final_snapshot = true` will not create a final automatic snapshot.

## Multi-environment deployments

If you run more than one environment per customer (e.g. a canary alongside production), deploy each one to a **separate AWS account**. AWS resources are isolated per account, so most resources — EKS cluster, IAM roles, DynamoDB tables, EMR Serverless apps, Secrets Manager entries, CloudWatch log groups — can keep identical names across environments with no collision. The exception is **S3 bucket names, which live in a single global namespace across all of AWS**, so you must disambiguate them with the `environment` variable.

### 1. AWS account setup

Create a separate AWS account per environment and configure one CLI profile per account in `~/.aws/config`:

```ini
[profile zipline-canary]
sso_session    = your-sso
sso_account_id = 111111111111
sso_role_name  = AdministratorAccess
region         = us-west-2

[profile zipline-prod]
sso_session    = your-sso
sso_account_id = 222222222222
sso_role_name  = AdministratorAccess
region         = us-west-2
```

(Long-lived access keys or `assume-role` also work — match whatever your org's standard is.)

Create a state-backend S3 bucket inside each account so each environment's Terraform state lives alongside the infrastructure it manages.

### 2. Per-environment tfvars

Maintain one `*.tfvars` file per environment. The only variable that has to differ is `environment`; the rest follow whatever you'd normally set:

```hcl
# canary.tfvars
customer_name          = "your-company"
environment            = "canary"                # → zipline-warehouse-canary-your-company
aws_account_id         = "111111111111"          # safety check: fail apply if AWS_PROFILE points elsewhere
region                 = "us-west-2"
artifact_prefix        = "s3://your-zipline-artifacts-canary"
terraform_state_bucket = "your-tfstate-canary"
terraform_state_file   = "zipline-canary.tfstate"
terraform_state_region = "us-west-2"
# ... other vars
```

```hcl
# prod.tfvars
customer_name          = "your-company"
environment            = ""                      # → zipline-warehouse-your-company (no prefix)
aws_account_id         = "222222222222"
region                 = "us-west-2"
artifact_prefix        = "s3://your-zipline-artifacts-prod"
terraform_state_bucket = "your-tfstate-prod"
terraform_state_file   = "zipline-prod.tfstate"
terraform_state_region = "us-west-2"
```

Setting `aws_account_id` is optional but strongly recommended once you have more than one environment — it wires the value into the AWS provider's `allowed_account_ids`, so terraform refuses to act if your resolved credentials point at the wrong account. An accidental `AWS_PROFILE=zipline-prod tofu apply -var-file=canary.tfvars` (or the reverse) fails fast instead of silently mutating the wrong stack. Leave it empty to skip the check.

Leaving `environment` empty in one of the envs is fine — it just means that account's S3 buckets keep the un-prefixed names, which is the safe default for upgrading an existing single-environment deployment without renaming any buckets.

### 3. Deploy

Set the AWS profile to target the right account, then init + apply against the matching tfvars file. Use `tofu init -reconfigure` whenever you switch environments — the S3 backend bucket changes, so the local `.terraform/` cache needs to be re-pointed.

```bash
cd zipline-aws

# Canary
AWS_PROFILE=zipline-canary tofu init -reconfigure -var-file=canary.tfvars
AWS_PROFILE=zipline-canary tofu apply -var-file=canary.tfvars

# Production
AWS_PROFILE=zipline-prod tofu init -reconfigure -var-file=prod.tfvars
AWS_PROFILE=zipline-prod tofu apply -var-file=prod.tfvars
```

### What `environment` actually changes

| Resource | `environment=""` | `environment="canary"` |
|----------|------------------|------------------------|
| Warehouse bucket | `zipline-warehouse-yourcompany` | `zipline-warehouse-canary-yourcompany` |
| Logs bucket | `zipline-logs-yourcompany` | `zipline-logs-canary-yourcompany` |
| EKS cluster, IAM roles, DynamoDB tables, EMR Serverless app, Secrets Manager, CloudWatch log groups, etc. | (unchanged — named after `customer_name`) | (unchanged — same as the env=`""` case) |

Only globally-unique resources (S3) take the prefix. Everything else is named after `customer_name` alone and relies on account isolation for uniqueness.

## Custom domains (HTTPS)

To expose services on your own domain with HTTPS, set the domain variables and follow these steps:

### 1. Deploy with domain variables

Use one shared domain for the whole stack:

```bash
tofu apply \
  -var 'zipline_custom_domain=zipline.yourcompany.com'
```

This exposes:

| Service | URL |
|---------|-----|
| UI | `https://zipline.yourcompany.com` |
| Hub | `https://zipline.yourcompany.com/services/hub` |
| Eval | `https://zipline.yourcompany.com/services/eval` |
| Fetcher | `https://zipline.yourcompany.com/services/fetcher` |

Or use one domain per service:

```bash
tofu apply \
  -var 'ui_domain=zipline.yourcompany.com' \
  -var 'hub_domain=zipline-hub.yourcompany.com' \
  -var 'fetcher_domain=zipline-fetcher.yourcompany.com' \
  -var 'eval_domain=zipline-eval.yourcompany.com'
```

By default, Terraform creates ACM certificates for each domain (initially in `Pending validation` state). In shared-domain mode, Terraform creates one certificate for `zipline_custom_domain`; in per-service mode, it creates one certificate per configured service domain.

To attach existing ACM certificates instead, pass the matching certificate ARN alongside each domain:

```bash
tofu apply \
  -var 'zipline_custom_domain=zipline.yourcompany.com' \
  -var 'zipline_custom_domain_cert_arn=arn:aws:acm:us-west-2:123456789012:certificate/example'
```

For per-service domains:

```bash
tofu apply \
  -var 'ui_domain=zipline.yourcompany.com' \
  -var 'ui_cert_arn=arn:aws:acm:us-west-2:123456789012:certificate/example' \
  -var 'hub_domain=zipline-hub.yourcompany.com' \
  -var 'hub_cert_arn=arn:aws:acm:us-west-2:123456789012:certificate/example'
```

For any configured domain with a matching certificate ARN, Terraform skips creating the ACM certificate and attaches the supplied certificate to the NLB. The certificate must be in the same AWS region as the NLB and cover the configured domain.

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

After deployment, shared-domain mode uses the UI Network Load Balancer (NLB) for all service paths. Per-service mode gives each service its own NLB. Get the NLB hostnames:

The `zipline_custom_domain_dns_setup` output includes `traffic_records` for either shared-domain or per-service mode. Each record has a `target_hostname` populated from the Kubernetes ingress controller Service when AWS has assigned the NLB hostname. If `target_hostname` is empty on the first apply, wait a minute or two for AWS to provision the NLB, then run `tofu apply` or `tofu refresh` again and re-check the output. The `target_command` field is a kubectl fallback for the same hostname.

**Via AWS Console:**
1. Go to **EC2** > **Load Balancers**
2. Each NLB's **DNS name** is shown in the Description tab

**Via CLI:**
```bash
kubectl get svc -A | grep LoadBalancer
```

For shared-domain mode, add one CNAME record pointing the custom domain to the UI NLB hostname:

| Type | Name | Target |
|------|------|--------|
| CNAME | `zipline` | `<ui-nlb-hostname>.elb.<region>.amazonaws.com` |

For per-service mode, add CNAME records in your DNS provider pointing each custom domain to its NLB hostname:

| Type | Name | Target |
|------|------|--------|
| CNAME | `zipline` | `<ui-nlb-hostname>.elb.<region>.amazonaws.com` |
| CNAME | `zipline-hub` | `<hub-nlb-hostname>.elb.<region>.amazonaws.com` |
| CNAME | `zipline-fetcher` | `<fetcher-nlb-hostname>.elb.<region>.amazonaws.com` |
| CNAME | `zipline-eval` | `<eval-nlb-hostname>.elb.<region>.amazonaws.com` |

For example, if the configured domain is `canary-aws.zipline.ai` and the DNS zone is `zipline.ai`, create a CNAME record with **Name** `canary-aws` and **Target** set to the UI NLB hostname. If your DNS provider asks for the full record name instead, use `canary-aws.zipline.ai`.

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

- S3: read/write on `zipline-warehouse-${customer_name}`, read-only on shared artifacts, and read-only on any buckets listed in `additional_data_buckets`
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
