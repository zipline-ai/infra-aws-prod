resource "aws_s3_bucket" "zipline_warehouse_bucket" {
  bucket = "zipline-warehouse-${lower(var.customer_name)}"
}

resource "aws_s3_bucket" "zipline_logs_bucket" {
  bucket = "zipline-logs-${lower(var.customer_name)}"
}

data "aws_iam_policy_document" "zipline_logs_bucket_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.control_plane_account_id}:role/zipline-logs-viewer"]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "${aws_s3_bucket.zipline_logs_bucket.arn}",
      "${aws_s3_bucket.zipline_logs_bucket.arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["${aws_iam_role.emr_serverless_role.arn}"]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "${aws_s3_bucket.zipline_logs_bucket.arn}",
      "${aws_s3_bucket.zipline_logs_bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "zipline_logs_bucket_policy" {
  bucket = aws_s3_bucket.zipline_logs_bucket.id
  policy = data.aws_iam_policy_document.zipline_logs_bucket_policy.json
}

output "aws_s3_bucket_arn" {
  value = aws_s3_bucket.zipline_warehouse_bucket.arn
}