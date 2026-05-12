# crucible-aws

Terraform that provisions the **Crucible** EKS cluster in the canary AWS
account (`345594603419` / `us-west-2`), sharing the existing canary VPC.
This is the AWS counterpart to the GCP `crucible-dev` GKE cluster and the
Azure `crucible-aks` AKS cluster.

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
