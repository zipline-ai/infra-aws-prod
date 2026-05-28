# crucible-aws

Terraform and Helm assets for deploying **Crucible** on AWS as an optional part
of a larger Zipline stack.

For most customer deployments, enable Crucible from `zipline-aws/` so it reuses
the same state, VPC, subnets, artifact bucket, warehouse bucket, and operator
access configuration as the rest of Zipline.

## Install With Zipline

Add the Crucible settings to `zipline-aws/terraform.tfvars`:

```hcl
deploy_crucible      = true
crucible_public_host = "crucible.yourcompany.com"

# Optional. Empty keeps the Crucible EKS API endpoint private-only.
crucible_eks_public_access_cidrs = ["203.0.113.10/32"]
```

Then apply the stack from `zipline-aws/`:

```sh
tofu init
tofu plan
tofu apply
```

When `deploy_crucible` is enabled, Terraform provisions:

| Resource | Notes |
|---|---|
| Crucible EKS cluster | Separate cluster named `<customer_name>-crucible-eks` unless `crucible_cluster_name` is set |
| Control node group | Tainted Graviton pool for Crucible control-plane pods and ingress |
| Data node group | Graviton pool for Spark and Flink workloads |
| S3 bucket | Event logs, checkpoints, jar staging, and archive backups |
| IRSA roles | Gateway role and Spark/Flink role, with Chronon artifact and warehouse bucket access wired from the Zipline stack |
| ACM certificate | DNS-validated certificate for `crucible_public_host` |
| nginx ingress | Internet-facing NLB with TLS terminated by ACM |
| Crucible Helm release | Installs the Crucible gateway, operators, metrics, logging, and history server from `charts/crucible` |

The same flag also sets `ENABLE_CRUCIBLE=true` on the Zipline orchestration Hub
and passes the `CRUCIBLE_*` connection settings it needs. When disabled, the Hub
continues to use the AWS EMR Serverless submitter.

## DNS

ACM requires DNS validation for `crucible_public_host`. Terraform outputs the
records as `crucible_acm_validation_records`. Add those CNAME records to your
DNS provider, then re-run `tofu apply` if the first apply timed out while
waiting for validation. You can also copy the same CNAME records from the ACM
certificate page in the AWS console.

After nginx ingress is created, Terraform outputs
`crucible_ingress_nlb_hostname`. Add a CNAME from `crucible_public_host` to that
NLB hostname.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `deploy_crucible` | `false` | Enables the optional Crucible cluster from `zipline-aws/` |
| `crucible_public_host` | `""` | Required when `deploy_crucible = true`; ACM cert hostname |
| `crucible_cluster_name` | `<customer_name>-crucible-eks` | Optional cluster name override |
| `crucible_bucket_name` | `zipline-crucible-<customer_name>` | Optional S3 bucket name override |
| `crucible_job_namespace` | `crucible-jobs` | Namespace where Crucible submits Spark and Flink jobs |
| `crucible_eks_public_access_cidrs` | `[]` | CIDRs allowed to reach the Crucible EKS API; empty means private-only |
| `crucible_ingress_nlb_subnet_ids` | Zipline stack subnets | Optional public subnet IDs for the ingress NLB |

## Standalone Use

The preferred install path is `zipline-aws/`, but `crucible-aws/` can still be
applied directly when you need to evaluate or operate Crucible separately.

Create `crucible-aws/terraform.tfvars`:

```hcl
region       = "us-west-2"
cluster_name = "crucible-eks"

shared_vpc_id     = "vpc-0123456789abcdef0"
shared_subnet_ids = ["subnet-0123456789abcdef0", "subnet-abcdef0123456789"]

crucible_bucket_name = "your-company-crucible"
public_host          = "crucible.yourcompany.com"

personnel_arns = [
  "arn:aws:iam::123456789012:role/your-admin-role",
]
```

Then run:

```sh
cd crucible-aws
tofu init
tofu plan
tofu apply
```

If you use the standalone path for a persistent environment, add an S3 backend
to `providers.tf` that matches your Terraform state bucket before applying.

## Helm Values

Terraform generates the AWS-specific Helm values from the cluster outputs:
Crucible bucket, gateway IRSA role, Spark/Flink IRSA role, public hostname, and
EKS OIDC issuer.

For standalone installs, set `crucible_chart_values_files` to add one or more
extra values files under `crucible-aws/`. Those files are merged after the
generated AWS defaults.

## Connect

```sh
aws eks update-kubeconfig --region <region> --name <crucible-cluster-name>
kubectl get nodes
```

## Charts

`charts/crucible/` contains the Crucible gateway, operators, metrics, logging,
and Spark History Server chart.

`charts/hub/` contains the Chronon Hub chart that can pair with this cluster
when the deployment includes Hub workloads.
