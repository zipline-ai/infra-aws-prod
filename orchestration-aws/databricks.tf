# Databricks service principal credentials for Unity Catalog integration
# The hub fetches these at startup to generate short-lived OAuth tokens
# for EMR jobs that read/write Databricks UC tables.
#
# All resources are conditional — only created when databricks_client_id is provided.

resource "aws_secretsmanager_secret" "databricks_sp" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-databricks-sp"
  description = "Databricks service principal credentials for Unity Catalog OAuth token generation"
}

resource "aws_secretsmanager_secret_version" "databricks_sp" {
  count     = var.databricks_client_id != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.databricks_sp[0].id
  secret_string = jsonencode({
    client_id     = var.databricks_client_id
    client_secret = var.databricks_client_secret
  })
}

resource "aws_iam_policy" "databricks_sp_secret_policy" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-DatabricksSpSecretReadAccess"
  description = "Allows reading the Databricks service principal credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.databricks_sp[0].arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "orchestration_irsa_databricks_sp_secret" {
  count      = var.databricks_client_id != "" ? 1 : 0
  role       = aws_iam_role.orchestration_irsa.name
  policy_arn = aws_iam_policy.databricks_sp_secret_policy[0].arn
}

# EMR instances also need to fetch the Databricks SP credentials at runtime
# to generate OAuth tokens for spark-submit jobs accessing Unity Catalog.
resource "aws_iam_role_policy_attachment" "emr_databricks_sp_secret" {
  count      = var.databricks_client_id != "" ? 1 : 0
  role       = "zipline_${var.name_prefix}_emr_serverless_role"
  policy_arn = aws_iam_policy.databricks_sp_secret_policy[0].arn
}