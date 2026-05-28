-- @requires: DATABRICKS_HOST DATABRICKS_CLIENT_ID DATABRICKS_CLIENT_SECRET DATABRICKS_WAREHOUSE AWS_REGION
--
-- Register Databricks Unity Catalog (Iceberg REST) with S3 storage. Use this
-- variant when running an AWS deployment that reads UC-managed Iceberg tables
-- whose data lives in S3. UC vends short-lived S3 credentials via the REST
-- protocol. OAuth is declared with StarRocks' REST-catalog security keys so
-- StarRocks can refresh tokens instead of relying on a one-time client token.
-- StarRocks falls back to the AWS SDK default chain (mounted ~/.aws files)
-- when vended creds are not honored for a given table.
--
-- After registration, query with:
--   SET CATALOG databricks_unity;
--   USE data;
--   SELECT * FROM uc_demo_v1__1 LIMIT 10;
-- Drop + recreate so re-running starrocks-init always picks up the latest
-- env values (e.g. rotated Databricks client secret). External catalogs are
-- metadata-only — no underlying data is touched.
DROP CATALOG IF EXISTS databricks_unity;
CREATE EXTERNAL CATALOG databricks_unity
PROPERTIES (
    "type" = "iceberg",
    "iceberg.catalog.type" = "rest",
    "iceberg.catalog.uri" = "${DATABRICKS_HOST}/api/2.1/unity-catalog/iceberg-rest",
    "iceberg.catalog.security" = "oauth2",
    "iceberg.catalog.oauth2.server-uri" = "${DATABRICKS_HOST}/oidc/v1/token",
    "iceberg.catalog.oauth2.credential" = "${DATABRICKS_CLIENT_ID}:${DATABRICKS_CLIENT_SECRET}",
    "iceberg.catalog.oauth2.scope" = "all-apis",
    "iceberg.catalog.warehouse" = "${DATABRICKS_WAREHOUSE}",
    "iceberg.catalog.vended-credentials-enabled" = "true",
    "aws.s3.region" = "${AWS_REGION}"
);