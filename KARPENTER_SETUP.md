# Karpenter Setup for EKS Cluster

This document describes the Karpenter autoscaling configuration that has been added to your EKS cluster for Flink workloads.

## What is Karpenter?

Karpenter is AWS's modern, high-performance Kubernetes node provisioner that automatically launches the right compute resources to handle your cluster's applications. It's designed to improve efficiency and reduce costs by:

- **Fast Scaling**: Provisions nodes in seconds vs minutes with Cluster Autoscaler
- **Smart Bin-Packing**: Better resource utilization through intelligent instance selection
- **Cost Optimization**: Can mix spot and on-demand instances automatically
- **Consolidation**: Automatically replaces or removes nodes for cost efficiency

## What Was Added

### 1. Infrastructure Components (`orchestration-aws/eks.tf`)

- **Karpenter Controller IAM Role**: IRSA role with permissions to manage EC2 instances
- **Karpenter Node IAM Role**: Role assumed by nodes that Karpenter provisions
- **SQS Interruption Queue**: Handles spot instance interruption notifications
- **EventBridge Rules**: Captures EC2 interruption events and forwards to SQS
- **Helm Release**: Installs Karpenter v1.1.1 into the `kube-system` namespace

### 2. NodePool Configurations (`orchestration-aws/karpenter.tf`)

Two NodePools have been created:

#### `flink-workload` NodePool (Priority: 10)
- **Purpose**: Primary pool for Flink jobs requiring compute, memory, or balanced resources
- **Capacity Types**: Both spot (for cost savings) and on-demand (for reliability)
- **Instance Types**:
  - Categories: c (compute), m (general purpose), r (memory optimized)
  - Generations: 5 and newer only
  - Sizes: large, xlarge, 2xlarge, 4xlarge, 8xlarge
- **Limits**: Up to 1000 CPUs and 1000Gi memory
- **Consolidation**: Aggressive consolidation after 1 minute of low utilization

#### `system-workload` NodePool (Priority: 1)
- **Purpose**: Lower-priority workloads, cost-optimized
- **Capacity Types**: Spot-only for maximum cost savings
- **Instance Types**:
  - Categories: t (burstable), c, m
  - Generations: 4 and newer
  - Sizes: medium, large, xlarge, 2xlarge
- **Limits**: Up to 100 CPUs and 100Gi memory
- **Consolidation**: Very aggressive (30 seconds), can replace 100% of nodes

### 3. EC2NodeClass Configuration

Defines the node template used by both NodePools:
- **AMI**: Amazon Linux 2023 (latest)
- **Subnets**: Uses both main and secondary subnets for multi-AZ availability
- **Security Groups**: Uses the EKS cluster security group
- **Volumes**: Encrypted EBS volumes using your existing KMS key
- **Metadata**: IMDSv2 required with hop limit 2 (for pod IAM access)

### 4. Outputs (`orchestration-aws/outputs.tf`)

New outputs added:
- `karpenter_controller_role_arn`: ARN of the controller IAM role
- `karpenter_node_role_arn`: ARN of the node IAM role
- `karpenter_interruption_queue_name`: SQS queue name
- `karpenter_interruption_queue_url`: SQS queue URL

## How It Works

1. **Pod Scheduling**: When a pod is created, Kubernetes tries to schedule it on existing nodes
2. **Provisioning Trigger**: If no suitable node exists, Karpenter detects the pending pod
3. **Instance Selection**: Karpenter analyzes the pod's resource requests and selects the most cost-effective instance type
4. **Node Launch**: Karpenter provisions the node (typically in 30-60 seconds)
5. **Pod Placement**: Once ready, the pod is scheduled on the new node
6. **Consolidation**: When nodes are underutilized, Karpenter consolidates workloads and terminates unnecessary nodes

## Deployment

To apply these changes:

```bash
cd /Users/davidhan/infra-aws-prod/zipline-aws
terraform init -upgrade  # Update kubectl provider if needed
terraform plan
terraform apply
```

## Verification

After deployment, verify Karpenter is running:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check Karpenter pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

# View NodePools
kubectl get nodepools

# View EC2NodeClasses
kubectl get ec2nodeclasses
```

You should see:
- Karpenter controller pod running in `kube-system`
- Two NodePools: `flink-workload` and `system-workload`
- One EC2NodeClass: `flink-workload`

## Testing Karpenter

To test if Karpenter provisions nodes:

```bash
# Create a test deployment that requires more resources than currently available
kubectl create deployment karpenter-test \
  --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7 \
  --replicas=10 \
  -n zipline-flink

# Set resource requests to trigger scaling
kubectl set resources deployment karpenter-test \
  --requests=cpu=1,memory=1Gi \
  -n zipline-flink

# Watch Karpenter logs
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter

# Check nodes
kubectl get nodes -L karpenter.sh/nodepool

# Clean up test
kubectl delete deployment karpenter-test -n zipline-flink
```

## Scaling Behavior for Flink Jobs

When you deploy Flink jobs:

1. **JobManager Pod**: Will be scheduled on existing nodes or trigger Karpenter provisioning
2. **TaskManager Pods**: As Flink scales task managers based on workload, Karpenter will provision additional nodes
3. **Spot/On-Demand Mix**: Karpenter will use spot instances when possible, falling back to on-demand for reliability
4. **Right-Sizing**: Karpenter selects instance types that efficiently fit your pod resource requests
5. **Cleanup**: When Flink jobs complete, Karpenter consolidates nodes to reduce costs

## Cost Optimization Tips

1. **Set Accurate Resource Requests**: Ensure your Flink pods have accurate CPU and memory requests
2. **Use Spot for Dev/Test**: For non-production Flink jobs, prefer spot instances by setting node affinity
3. **Monitor Consolidation**: Check CloudWatch or Kubernetes events to see consolidation activity
4. **Adjust Limits**: Modify NodePool limits in `karpenter.tf` if you need higher capacity

## Node Selectors for Flink Jobs

To target specific NodePools in your Flink deployments:

```yaml
# For Flink workloads (higher priority)
spec:
  podTemplate:
    spec:
      nodeSelector:
        karpenter.sh/nodepool: flink-workload

# For system workloads (lower priority, spot-only)
spec:
  podTemplate:
    spec:
      nodeSelector:
        karpenter.sh/nodepool: system-workload
```

## Troubleshooting

### Pods Stuck in Pending State

```bash
# Check pod events
kubectl describe pod <pod-name> -n zipline-flink

# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=100

# Check NodePool status
kubectl describe nodepool flink-workload
```

### No Nodes Being Provisioned

Common issues:
- Resource limits reached (check NodePool `.spec.limits`)
- No suitable instance types available in AWS region
- IAM role permissions missing
- Subnet or security group issues

### Spot Interruptions

Karpenter handles spot interruptions automatically:
- 2-minute warning received via SQS
- Workloads are drained and rescheduled
- Check logs: `kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter | grep interruption`

## Monitoring

Key metrics to monitor:

1. **CloudWatch Metrics**:
   - EC2 instance launches/terminations
   - SQS queue depth (interruption queue)

2. **Kubernetes Events**:
   ```bash
   kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep karpenter
   ```

3. **Node Status**:
   ```bash
   kubectl get nodes -o wide -L karpenter.sh/nodepool,karpenter.sh/capacity-type
   ```

## Configuration Tuning

To adjust Karpenter behavior, edit `orchestration-aws/karpenter.tf`:

- **Increase capacity limits**: Modify `.spec.limits.cpu` and `.spec.limits.memory`
- **Change instance types**: Modify `.spec.requirements` to include/exclude instance families
- **Adjust consolidation**: Change `.spec.disruption.consolidateAfter` for more/less aggressive consolidation
- **Spot vs On-Demand ratio**: Adjust `.spec.requirements` for `karpenter.sh/capacity-type`

After changes, run:
```bash
terraform apply
```

## Comparison: Existing Node Group vs Karpenter

| Feature | EKS Node Group (existing) | Karpenter (new) |
|---------|--------------------------|-----------------|
| Node provisioning | Manual scaling, fixed instance type | Automatic, diverse instance types |
| Scaling speed | 3-5 minutes | 30-60 seconds |
| Instance selection | Fixed (m5.2xlarge) | Dynamic based on workload |
| Cost optimization | Limited | Excellent (spot, bin-packing, consolidation) |
| Management | AWS-managed Auto Scaling Groups | Karpenter controller |

The existing node group will continue to run alongside Karpenter. Consider gradually reducing the node group size as you gain confidence in Karpenter.

## Next Steps

1. **Deploy the changes**: Run `terraform apply`
2. **Test with sample workload**: Deploy a test Flink job
3. **Monitor behavior**: Watch node provisioning and consolidation
4. **Adjust settings**: Fine-tune instance types and limits based on your workload patterns
5. **Gradually migrate**: Move workloads from fixed node group to Karpenter-managed nodes
6. **Set up alerting**: Create CloudWatch alarms for capacity limits and provisioning failures

## References

- [Karpenter Documentation](https://karpenter.sh/)
- [AWS Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Karpenter NodePool API](https://karpenter.sh/docs/concepts/nodepools/)
- [EC2NodeClass API](https://karpenter.sh/docs/concepts/nodeclasses/)
