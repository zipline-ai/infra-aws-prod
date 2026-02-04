# S3 buckets for Zipline data warehouse and logs

resource "aws_s3_bucket" "warehouse" {
  bucket = "zipline-warehouse-${lower(var.customer_name)}"

  tags = {
    Name = "zipline-warehouse-${lower(var.customer_name)}"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "zipline-logs-${lower(var.customer_name)}"

  tags = {
    Name = "zipline-logs-${lower(var.customer_name)}"
  }
}

# Bucket policy for logs - only allow EMR profile role access
data "aws_iam_policy_document" "logs_bucket_policy" {
  statement {
    sid    = "EMRProfileAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.emr_profile_role.arn]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "logs_bucket_policy" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket_policy.json
}

# Enable versioning for warehouse bucket (data protection)
resource "aws_s3_bucket_versioning" "warehouse" {
  bucket = aws_s3_bucket.warehouse.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for both buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "warehouse" {
  bucket = aws_s3_bucket.warehouse.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for both buckets
resource "aws_s3_bucket_public_access_block" "warehouse" {
  bucket = aws_s3_bucket.warehouse.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
