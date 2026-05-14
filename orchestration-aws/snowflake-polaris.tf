# Snowflake Open Catalog (Polaris, Iceberg REST) for S3-backed warehouses. Enables access for
# the data explorer.
#
# All resources are conditional — only created when snowflake_polaris_client_id is provided.

resource "aws_secretsmanager_secret" "snowflake_polaris_sp" {
  count       = var.snowflake_polaris_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-snowflake-polaris-sp"
  description = "Databricks service principal credentials for Unity Catalog OAuth token generation"
}

resource "aws_secretsmanager_secret_version" "snowflake_polaris_sp" {
  count     = var.snowflake_polaris_client_id != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.snowflake_polaris_sp[0].id
  secret_string = jsonencode({
    client_id     = var.snowflake_polaris_client_id
    client_secret = var.snowflake_polaris_client_secret
  })
}

resource "aws_iam_policy" "snowflake_polaris_sp_secret_policy" {
  count       = var.snowflake_polaris_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-SnowflakePolarisSpSecretReadAccess"
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
        Resource = [aws_secretsmanager_secret.snowflake_polaris_sp[0].arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "orchestration_irsa_snowflake_polaris_sp_secret" {
  count      = var.snowflake_polaris_client_id != "" ? 1 : 0
  role       = aws_iam_role.orchestration_irsa.name
  policy_arn = aws_iam_policy.snowflake_polaris_sp_secret_policy[0].arn
}