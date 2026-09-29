# Databricks service principal credentials for Unity Catalog integration.
# The JSON secret below is synced into the cluster for the eval service. EMR jobs read the
# per-value secrets further down at startup; the hub no longer receives the credentials.
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
# Per-value secrets that jobs resolve at startup through NAME_VAULT_URI refs in the team env
# (DATABRICKS_CLIENT_SECRET_VAULT_URI, DATABRICKS_CREDENTIAL_VAULT_URI), so the hub never holds
# or submits the plaintext. The credential is the Iceberg REST catalog `client_id:client_secret`.
resource "aws_secretsmanager_secret" "databricks_client_secret" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-databricks-client-secret"
  description = "Databricks service principal client secret, read by jobs via DATABRICKS_CLIENT_SECRET_VAULT_URI"
}

resource "aws_secretsmanager_secret_version" "databricks_client_secret" {
  count         = var.databricks_client_id != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.databricks_client_secret[0].id
  secret_string = var.databricks_client_secret
}

resource "aws_secretsmanager_secret" "databricks_credential" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-databricks-credential"
  description = "Databricks service principal client_id:client_secret, read by jobs via DATABRICKS_CREDENTIAL_VAULT_URI"
}

resource "aws_secretsmanager_secret_version" "databricks_credential" {
  count         = var.databricks_client_id != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.databricks_credential[0].id
  secret_string = "${var.databricks_client_id}:${var.databricks_client_secret}"
}

resource "aws_iam_policy" "databricks_job_secrets_policy" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-DatabricksJobSecretsReadAccess"
  description = "Allows EMR Serverless jobs to read the Databricks secrets referenced by *_VAULT_URI"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.databricks_client_secret[0].arn,
          aws_secretsmanager_secret.databricks_credential[0].arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_databricks_job_secrets" {
  count      = var.databricks_client_id != "" ? 1 : 0
  role       = "zipline_${var.name_prefix}_emr_serverless_role"
  policy_arn = aws_iam_policy.databricks_job_secrets_policy[0].arn
}
