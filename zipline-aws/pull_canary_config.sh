#!/bin/bash

aws s3 cp s3://zipline-canary-vars/.terraform.lock.hcl .
aws s3 cp s3://zipline-canary-vars/terraform.tfvars .
