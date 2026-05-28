-- @requires: AWS_REGION
--
-- Register an external catalog pointing at AWS Glue Data Catalog with S3
-- warehouse. StarRocks reads Iceberg metadata from Glue and Parquet from S3
-- directly — it does NOT create a local catalog or copy any data.
--
-- Credentials use the AWS SDK default chain via the mounted ~/.aws files
-- (AWS_SHARED_CREDENTIALS_FILE / AWS_PROFILE on the starrocks container).
--
-- After registration, query with:
--   SET CATALOG aws_glue;
--   USE data;
--   SELECT * FROM aws_demo_v1__1 LIMIT 10;
-- Drop + recreate so re-running starrocks-init always picks up the latest
-- env values (e.g. rotated AWS profile, region change). External catalogs
-- are metadata-only — no underlying data is touched.
DROP CATALOG IF EXISTS aws_glue;
CREATE EXTERNAL CATALOG aws_glue
PROPERTIES (
    "type" = "iceberg",
    "iceberg.catalog.type" = "glue",
    "aws.glue.use_aws_sdk_default_behavior" = "true",
    "aws.glue.region" = "${AWS_REGION}",
    "aws.s3.use_aws_sdk_default_behavior" = "true",
    "aws.s3.region" = "${AWS_REGION}"
);