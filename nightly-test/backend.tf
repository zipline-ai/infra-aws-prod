terraform {
  backend "s3" {
    bucket         = "zipline-nightly-tf-state"
    key            = "nightly-test/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "zipline-nightly-tf-locks"
  }
}
