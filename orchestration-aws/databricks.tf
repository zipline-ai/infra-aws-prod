# Databricks service principal credentials for Unity Catalog integration.
# EMR jobs read the secrets at startup through NAME_VAULT_URI refs in the team env
# (DATABRICKS_CLIENT_SECRET_VAULT_URI, DATABRICKS_CREDENTIAL_VAULT_URI), so the hub never holds
# or submits them. Eval gets the client secret through the CSI-synced k8s secret. The client ID
# isn't secret and reaches the hub and eval as a plain env var.
#
# All resources are conditional — only created when databricks_client_id is provided.

resource "aws_secretsmanager_secret" "databricks_client_secret" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-databricks-client-secret"
  description = "Databricks service principal client secret"
}

resource "aws_secretsmanager_secret_version" "databricks_client_secret" {
  count         = var.databricks_client_id != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.databricks_client_secret[0].id
  secret_string = var.databricks_client_secret
}

# `client_id:client_secret`, the Iceberg REST catalog credential format.
resource "aws_secretsmanager_secret" "databricks_credential" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-zipline-databricks-credential"
  description = "Databricks service principal client_id:client_secret"
}

resource "aws_secretsmanager_secret_version" "databricks_credential" {
  count         = var.databricks_client_id != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.databricks_credential[0].id
  secret_string = "${var.databricks_client_id}:${var.databricks_client_secret}"
}

resource "aws_iam_policy" "databricks_secrets_policy" {
  count       = var.databricks_client_id != "" ? 1 : 0
  name        = "${var.name_prefix}-DatabricksSecretsReadAccess"
  description = "Allows reading the Databricks service principal secrets from Secrets Manager"

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

# The hub and eval pods share this service account; the CSI driver uses it to sync the client
# secret for eval.
resource "aws_iam_role_policy_attachment" "orchestration_irsa_databricks_secrets" {
  count      = var.databricks_client_id != "" ? 1 : 0
  role       = aws_iam_role.orchestration_irsa.name
  policy_arn = aws_iam_policy.databricks_secrets_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "emr_databricks_secrets" {
  count      = var.databricks_client_id != "" ? 1 : 0
  role       = "zipline_${var.name_prefix}_emr_serverless_role"
  policy_arn = aws_iam_policy.databricks_secrets_policy[0].arn
}

# Flink pods on EKS resolve DATABRICKS_CREDENTIAL_VAULT_URI (and friends) at job startup
# via JobSecrets → VaultSecretProvider → AWS Secrets Manager, so the Flink IRSA role needs
# GetSecretValue on the same ARNs that the hub + EMR Serverless already read. Attached on
# whichever role the active submit route uses (EKS Flink via EksFlinkSubmitter vs. the
# in-cluster compute path), gated on in_cluster_compute_enabled to match the role itself.
resource "aws_iam_role_policy_attachment" "flink_job_databricks_secrets" {
  count = var.databricks_client_id != "" && !var.in_cluster_compute_enabled ? 1 : 0

  role       = aws_iam_role.flink_job_execution[0].name
  policy_arn = aws_iam_policy.databricks_secrets_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "flink_compute_databricks_secrets" {
  count = var.databricks_client_id != "" && var.in_cluster_compute_enabled ? 1 : 0

  role       = aws_iam_role.flink_compute_execution[0].name
  policy_arn = aws_iam_policy.databricks_secrets_policy[0].arn
}
