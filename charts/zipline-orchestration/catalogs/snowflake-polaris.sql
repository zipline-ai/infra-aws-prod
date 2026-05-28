-- @requires: SNOWFLAKE_ACCOUNT SNOWFLAKE_CLIENT_ID SNOWFLAKE_CLIENT_SECRET POLARIS_WAREHOUSE POLARIS_PRINCIPAL_ROLE
--
-- Register Snowflake Open Catalog (Polaris, Iceberg REST) for S3-backed
-- warehouses. Polaris vends short-lived S3 credentials via the
-- `X-Iceberg-Access-Delegation: vended-credentials` header, so no explicit
-- AWS auth block is needed — StarRocks consumes the vended creds and falls
-- back to the SDK default chain (mounted ~/.aws files) for tables Polaris
-- doesn't vend creds for.
--
-- For ADLS-backed Polaris warehouses, use `snowflake-polaris-azure.sql`
-- instead — Iceberg-on-Azure in StarRocks needs explicit `azure.adls2.*`
-- service principal credentials to construct the `abfss://` filesystem
-- handler; vended creds aren't sufficient there.
--
-- Env-var naming mirrors `chronon/scripts/interactive/snowflake_session.py`
-- so a single set of credentials works for both the local PySpark script
-- and the StarRocks data explorer.
--
-- Drop + recreate so re-running starrocks-init always picks up the latest
-- env values (e.g. rotated client secret). External catalogs are
-- metadata-only — no underlying data is touched.
--
-- After registration, query with:
--   SET CATALOG snowflake_polaris;
--   USE demo;
--   SELECT * FROM checkouts__0 LIMIT 10;
DROP CATALOG IF EXISTS snowflake_polaris;
CREATE EXTERNAL CATALOG snowflake_polaris
PROPERTIES (
    "type" = "iceberg",
    "iceberg.catalog.type" = "rest",
    "iceberg.catalog.uri" = "https://${SNOWFLAKE_ACCOUNT}.snowflakecomputing.com/polaris/api/catalog",
    "iceberg.catalog.security" = "oauth2",
    "iceberg.catalog.oauth2.credential" = "${SNOWFLAKE_CLIENT_ID}:${SNOWFLAKE_CLIENT_SECRET}",
    "iceberg.catalog.oauth2.scope" = "PRINCIPAL_ROLE:${POLARIS_PRINCIPAL_ROLE}",
    "iceberg.catalog.warehouse" = "${POLARIS_WAREHOUSE}",
    "iceberg.catalog.vended-credentials-enabled" = "true",
    "iceberg.catalog.header.X-Iceberg-Access-Delegation" = "vended-credentials"
);