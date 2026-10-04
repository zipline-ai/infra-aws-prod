# Nightly Test Bootstrap

One-time setup for the Terraform remote state backend used by the nightly E2E test infrastructure.

## Resources Created

- **S3 bucket** `zipline-nightly-tf-state` — versioned, encrypted, private
- **DynamoDB table** `zipline-nightly-tf-locks` — state locking

## Setup

```bash
cd nightly-test/bootstrap
terraform init
terraform apply
```

This only needs to be run once. After this, the `nightly-test/` wrapper module can use the S3 backend for state storage.
