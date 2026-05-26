# crucible-aws

Terraform that provisions the **Crucible** EKS cluster. The checked-in files in
this directory are the env-agnostic skeleton — concrete network IDs, bucket
names, public-API CIDR allow-list, etc. live in `s3://zipline-canary-vars/`
(shared with zipline-aws and other canary modules) and are pulled in via
`./pull_canary_config.sh` before `terraform apply`.

## Workflow

```sh
cd crucible-aws

# First-time / new clone — fetch canary tfvars + canary-only overlay from S3.
./pull_canary_config.sh

terraform init
terraform plan
terraform apply

# After editing canary-only local config, push back to S3 so the next operator
# pulls your change.
./push_canary_config.sh
```

`pull_canary_config.sh` writes `crucible.auto.tfvars` with the concrete values
for the variables declared in `variables.tf` (VPC/subnet tags, ingress NLB
subnet tags, bucket name, public host, public-API CIDRs, chronon bucket lists).
It also pulls gitignored canary-only Terraform overlays and chart values for
Zipline-managed environment details that should not become part of the
customer-facing API. Terraform auto-loads `*.auto.tfvars` so no `-var-file`
flag is needed.

The skeleton's `chronon_irsa.tf` reads the chronon bucket lists from those
tfvars and conditionally attaches an inline policy to the spark IAM role —
the *shape* of the policy stays in this prod-facing tree (every
chronon-on-EKS deployment needs the same statement structure), only the
bucket NAMES vary per environment.

`.tfvars` files, canary-only overlays, and `*-canary.yaml`/`*-dev.yaml` chart
values are gitignored at the repo root so they can't leak into this tree.
`.terraform.lock.hcl` stays in version control alongside the skeleton (single
source of truth for provider versions).

The canary overlay has its own provider dependencies. `pull_canary_config.sh`
therefore replaces the local `.terraform.lock.hcl` with
`s3://zipline-canary-vars/crucible.terraform.lock.hcl`, and
`push_canary_config.sh` uploads that canary lockfile back to S3. Do not commit
the S3-synced canary lockfile to this tree.

The `crucible` Helm release is managed by Terraform from `crucible.tf`. Its
default values file is `charts/crucible/values-eks-canary.yaml`, which is
pulled from S3 by `pull_canary_config.sh`. Before the first Terraform apply
against the existing canary deployment, import the live release once:

```sh
tofu import helm_release.crucible crucible-system/crucible
```

## What lives in this directory (skeleton)

Originally the canary AWS account (`345594603419` / `us-west-2`), sharing
the existing canary VPC. AWS counterpart to the GCP `crucible-dev` GKE
cluster and the Azure `crucible-aks` AKS cluster.

## Scope

| Resource | Notes |
|---|---|
| `aws_eks_cluster.crucible` | `crucible-eks`, version 1.34, public+private API |
| `aws_iam_role.cluster` + policy attachments | `AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController` |
| `aws_security_group.cluster` + HTTPS ingress rule | Control-plane SG |
| `aws_eks_node_group.control` | Tainted Graviton control-plane pool for Hub, ingress, and Crucible services |
| `aws_eks_node_group.default` | Graviton data-plane pool for Chronon engine Spark/Flink pods |
| `aws_iam_role.node` + policy attachments | `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |
| `aws_iam_openid_connect_provider.oidc` | Required by IRSA |
| `aws_eks_access_entry` + access policy associations | Optional, driven by `var.personnel_arns` |
| `helm_release.crucible` | Installs/updates the Crucible chart from `charts/crucible` with S3-backed canary values |

## Public ingress DNS

The nginx ingress controller provisions an AWS NLB. Set
`ingress_nlb_subnet_name_tags` to public subnet Name tags when you need to pin
the public ingress NLB to specific subnets. When unset, Terraform leaves subnet
selection to Kubernetes/AWS.

This skeleton does not manage DNS records. After apply, point `public_host` at
the `ingress_nlb_hostname` output using your DNS provider.

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

## Hub chart

`charts/hub/` is the Helm chart for the Chronon Hub that pairs with this
cluster. It is kept under `crucible-aws/` rather than the top-level `charts/`
directory because it is Crucible-specific — deployments that don't run
Crucible never render it. It lands service pods on the tainted control node
group (`aws_eks_node_group.control`); Spark/Flink engine pods stay on the
default data-plane pool. Install it after `terraform apply`:

```sh
helm install hub crucible-aws/charts/hub \
  -f crucible-aws/charts/hub/hub-values-eks-dev.yaml \
  --set hub.jarUri=s3://<bucket>/release/<version>/jars/k8s_assembly.jar \
  -n crucible-system
```
