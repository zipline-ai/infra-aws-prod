###############################################################################
# Crucible artifacts bucket
#
# Stores: spark event logs, flink checkpoints/savepoints, jar staging for CI.
# Counterpart to GCS gs://crucible-dev-bucket and Azure abfss://crucible@ziplineai2.
###############################################################################

resource "aws_s3_bucket" "crucible" {
  bucket = var.crucible_bucket_name

  tags = {
    Name = var.crucible_bucket_name
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "crucible" {
  bucket = aws_s3_bucket.crucible.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "crucible" {
  bucket = aws_s3_bucket.crucible.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CI jars accumulate fast; expire the `release/ci-*` prefix after 7 days.
resource "aws_s3_bucket_lifecycle_configuration" "crucible" {
  bucket = aws_s3_bucket.crucible.id

  rule {
    id     = "ci-jar-cleanup"
    status = "Enabled"

    filter {
      prefix = "release/ci-"
    }

    expiration {
      days = 7
    }

    # Reap orphaned multipart-upload parts on the same cadence so a failed
    # `aws s3 cp` doesn't leak storage cost indefinitely.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
