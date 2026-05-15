# crucible-aws

Terraform that provisions the **Crucible** EKS cluster. The files in this
directory are the env-agnostic skeleton — concrete network IDs, bucket names,
public-API CIDR allow-list, and account-specific IRSA grants live in
`s3://zipline-canary-vars/crucible/` and are pulled in via
`./pull_canary_config.sh` before `terraform apply`. This mirrors the
`zipline-aws/` module's split.

## Workflow

```sh
cd crucible-aws

# First-time / new clone — fetch canary tfvars + extra IAM grants from S3.
./pull_canary_config.sh

terraform init
terraform plan
terraform apply

# After editing canary_*.tf or terraform.tfvars locally, push back to S3 so
# the next operator pulls your change.
./push_canary_config.sh
```

`pull_canary_config.sh` writes:

- `terraform.tfvars` — concrete values for `shared_vpc_name_tag`,
  `shared_subnet_name_tags`, `crucible_bucket_name`, `public_host`,
  `eks_endpoint_public_access`, `eks_public_access_cidrs`, etc.
- `canary_chronon_grants.tf` — extra `aws_iam_role_policy` attached to
  `aws_iam_role.spark` that grants chronon-canary S3 / Glue / DynamoDB
  access. Empty/missing for non-canary environments.
- `.terraform.lock.hcl` — pinned provider versions.

All three patterns are gitignored at the repo root so they can't leak into
this prod-facing tree.

## What lives in this directory (skeleton)

Originally the canary AWS account (`345594603419` / `us-west-2`), sharing
the existing canary VPC. AWS counterpart to the GCP `crucible-dev` GKE
cluster and the Azure `crucible-aks` AKS cluster.

## Scope (this PR — cluster only)

| Resource | Notes |
|---|---|
| `aws_eks_cluster.crucible` | `crucible-eks`, version 1.34, public+private API |
| `aws_iam_role.cluster` + policy attachments | `AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController` |
| `aws_security_group.cluster` + HTTPS ingress rule | Control-plane SG |
| `aws_eks_node_group.default` | Single Graviton (arm64) pool, m7g.large, autoscale 1-5 |
| `aws_iam_role.node` + policy attachments | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |
| `aws_iam_openid_connect_provider.oidc` | Required by IRSA |
| `aws_eks_access_entry` + access policy associations | Optional, driven by `var.personnel_arns` |

## Follow-up PRs

- **IRSA roles**: `crucible-gateway-irsa` (S3 + EKS access; trust `crucible-system/crucible`), `crucible-spark-irsa` (S3 RW; trust `test-ns-*/{spark-operator-spark,flink}`). Mirrors `crucible-spark@crucible-io.iam.gserviceaccount.com` on GCP and `crucible-spark-identity` on Azure.
- **S3 bucket**: `crucible-artifacts-canary` for jar staging + spark event logs + flink checkpoints. Counterpart to GCS `crucible-dev-bucket` and the `ziplineai2/crucible` Azure container.
- **GitHub OIDC role**: `github_actions_crucible` with trust to GitHub Actions OIDC and permissions to push jars to S3 + assume into the IRSA roles. Wires into `crucible_integration_test_aws.yaml` in platform.
- **NVMe + spot node groups**: mirrors AKS `nvme` / `spotnvme` pools.

## Apply

```sh
cd crucible-aws
terraform init
terraform plan
terraform apply
```

State lives in `s3://zipline-ai-opentofu-state-bucket/opentofu-crucible-state`
(separate key from canary so they're decoupled).

After apply:

```sh
aws eks update-kubeconfig --region us-west-2 --name crucible-eks
kubectl get nodes
```

## VPC

Shares the canary VPC (looked up by Name tag `zipline-canary-vpc` plus subnet
Name tags). If/when crucible warrants isolation, switch to a dedicated VPC by
adding the network resources here and dropping the data lookups in `vpc.tf`.
