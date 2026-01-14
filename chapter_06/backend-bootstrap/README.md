# Backend Bootstrap

## Purpose

This directory creates the S3 bucket that will store Terraform state files for the dev and prod workspaces. It uses **local state** to solve the chicken-egg problem: you can't use remote state to create the remote state storage.

## Usage

**Run once locally (NOT via Spacelift):**

```bash
cd backend-bootstrap
terraform init
terraform apply
```

This creates:

- S3 bucket for state storage (with versioning and encryption)
- Resource group for AWS Console organization
- Outputs the bucket name for workspace configuration

## Current Deployment

**Bucket name:** `tfstate-tg4dsqccl4c0ohyw-state-bucket`
**Region:** `us-east-1`
**Resources created:** 6 (S3 bucket, versioning, encryption, public access block, resource group, random string)

## Why State File is NOT Committed

⚠️ **IMPORTANT:** The `terraform.tfstate` file in this directory is **gitignored** and NOT committed to the repository.

**Good reasons to not check-in your .tfstate file:**

- Contains sensitive AWS account information (account IDs, ARNs)
- Contains resource metadata that could expose infrastructure details
- Security best practice: never commit state files to version control
- Each AWS account should have its own bootstrap bucket

## For Other Users

If someone else wants to use this repository:

1. They should run `terraform apply` in this directory to create their own S3 bucket
2. They'll get a different bucket name (random suffix ensures uniqueness)
3. They'll update their workspace configurations to use their bucket name

## Cleanup

To destroy the S3 bucket (after destroying all workspaces):

```bash
terraform destroy
```

**Note:** The bucket must be empty before Terraform can destroy it. Ensure all workspace state files are removed first.
