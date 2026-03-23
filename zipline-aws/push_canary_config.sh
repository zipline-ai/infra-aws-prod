#!/bin/bash

aws s3 cp ./.terraform.lock.hcl s3://zipline-canary-vars/
aws s3 cp ./terraform.tfvars s3://zipline-canary-vars/
aws s3 cp ./github.tf s3://zipline-canary-vars/