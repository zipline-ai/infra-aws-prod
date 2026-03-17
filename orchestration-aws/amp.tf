# AWS Managed Prometheus (AMP) Workspace
# Provides a fully managed Prometheus-compatible monitoring service
# for storing and querying metrics from EKS workloads

resource "aws_prometheus_workspace" "main" {
  alias = "${var.name_prefix}-prometheus"

  tags = {
    Name = "${var.name_prefix}-amp-workspace"
  }
}

# CloudWatch Logs group for AMP alerts (optional but recommended)
resource "aws_cloudwatch_log_group" "amp_alerts" {
  name              = "/aws/prometheus/${var.name_prefix}"
  retention_in_days = 7

  tags = {
    Name = "${var.name_prefix}-amp-alerts"
  }
}

# Scrape config for the AWS managed collector.
# Defined as a local to keep YAML at zero indentation (avoids heredoc stripping issues).
locals {
  amp_scrape_config = <<-EOT
global:
  scrape_interval: 30s
  external_labels:
    cluster: ${aws_eks_cluster.main.name}
scrape_configs:
  - job_name: pod_exporter
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name
  - job_name: cadvisor
    scheme: https
    authorization:
      type: Bearer
      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - replacement: kubernetes.default.svc:443
        target_label: __address__
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
EOT
}

# AWS Managed Collector: scrapes metrics from EKS and remote-writes to AMP.
# Because the cluster uses API_AND_CONFIG_MAP auth mode, AWS automatically
# creates an EKS access entry for the scraper's service-linked role.
resource "aws_prometheus_scraper" "main" {
  source {
    eks {
      cluster_arn        = aws_eks_cluster.main.arn
      security_group_ids = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
      subnet_ids         = [var.main_subnet_id, var.secondary_subnet_id]
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.main.arn
    }
  }

  scrape_configuration = local.amp_scrape_config

  tags = {
    Name = "${var.name_prefix}-amp-scraper"
  }

  depends_on = [aws_eks_node_group.default]
}
