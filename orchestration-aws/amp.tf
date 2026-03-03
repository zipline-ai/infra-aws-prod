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
