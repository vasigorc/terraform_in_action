# Terraform in Action - Learning Repository

Working through "Terraform in Action" to master infrastructure as code fundamentals and production patterns.

## Overview

This repository contains hands-on exercises and examples from the book "Terraform in Action", focusing on AWS infrastructure provisioning, state management, modules, and team collaboration workflows.

**Current Status:**

- ✅ Chapters 1-3: Completed (basic workflow, resources, state)
- 🔄 Chapter 4: In progress (modules and composition)
- 📚 Chapters 5+: Upcoming (multi-env, remote state, testing)

## Prerequisites

- **Terraform:** v1.12.0+ ([download](https://www.terraform.io/downloads))
- **AWS Account:** Personal account with configured credentials
- **AWS CLI:** Configured with `~/.aws/credentials` and `~/.aws/config`
- **Git:** For version control

## Development Environment

### Nix Shell (Recommended)

This project uses Nix for reproducible development environments. The following packages are available in the Nix shell:

```nix
terraform              # Terraform CLI v1.12.0
tflint                 # Terraform linter
terraform-docs         # Generate docs from modules
tfsec                  # Security scanner for Terraform
```

**Setup:**

1. Ensure Nix is installed with unfree packages enabled (`config.allowUnfree = true`)
2. Enter the Nix shell in your project directory
3. Verify installation: `terraform --version`

### NeoVim Setup

Using LazyVim with the Terraform language extra:

```lua
{
  import = "lazyvim.plugins.extras.lang.terraform"
}
```

**Features provided:**

- **LSP:** `terraformls` via Mason (autocomplete, go-to-definition, hover docs)
- **Syntax:** TreeSitter for HCL/Terraform highlighting
- **Linting:** tflint integration
- **Formatting:** `terraform fmt` on save

**Verify setup:**

```vim
:LspInfo         " Should show terraformls attached
:Mason           " Should show terraform-ls installed
:TSInstallInfo   " Should show terraform syntax installed
```

### Oh My Zsh Terraform Plugin

Useful aliases and completions for Terraform commands. See the [official plugin documentation](https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/terraform/README.md) for available shortcuts.

**Common aliases:**

- `tf` → `terraform`
- `tfi` → `terraform init`
- `tfp` → `terraform plan`
- `tfa` → `terraform apply`
- `tfd` → `terraform destroy`

## Repository Structure

```
terraform_in_action/
├── chapter_01/         # Basic Terraform workflow
├── chapter_02/         # Resources and dependencies
├── chapter_03/         # Variables and state
├── chapter_04/         # Modules and composition
└── ...

# Each chapter contains:
chapter_*/
├── main.tf            # Primary resource definitions
├── variables.tf       # Input variables
├── outputs.tf         # Output values
├── providers.tf       # Provider configuration (if separate)
└── .terraform.lock.hcl # Provider dependency lock
```

## Getting Started

### Running an Exercise

```bash
# Navigate to chapter directory
cd chapter_01

# Initialize Terraform (download providers)
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# IMPORTANT: Destroy resources when done
terraform destroy
```

### Version Constraints

All chapters use consistent version constraints:

```hcl
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## Common Workflows

### Standard Development Cycle

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Clean up
terraform destroy
```

### Updating Provider Versions

```bash
# Upgrade to latest compatible versions
terraform init -upgrade

# Check current versions
terraform providers

# Review lock file
cat .terraform.lock.hcl
```

### Debugging

```bash
# Verbose logging
TF_LOG=DEBUG terraform plan

# Inspect state
terraform show
terraform state list
terraform state show aws_instance.example
```

## AWS Cost Management ⚠️

**Using personal AWS account - cost control is critical.**

### Safety Rules

- ✅ Always use free tier resources when possible
- ✅ Default to `t2.micro` or `t3.micro` instances
- ✅ Run `terraform destroy` immediately after exercises
- ✅ Set billing alerts in AWS Console ($5, $10, $20)
- ⚠️ **NEVER CREATE** without discussion:
  - NAT Gateways ($0.045/hr)
  - Application Load Balancers ($0.0225/hr)
  - RDS instances
  - Resources in multiple AZs
- ⚠️ **ALWAYS DESTROY** resources after testing (don't leave running overnight)

### Code Organization

- Use modules to avoid repeating resource patterns (DRY principle)
- Separate state per environment (dev/staging/prod)
- Pin provider versions in production
- Use remote backends (S3 + DynamoDB) for team collaboration

### Workflow

- Run `terraform fmt` before commits
- Review `terraform plan` output carefully
- Use version control for all `.tf` files
- Document infrastructure decisions in commit messages

## Terraform Licensing

Terraform uses the Business Source License (BSL 1.1) since v1.6.0. This allows:

- ✅ Personal learning and development
- ✅ Production infrastructure work
- ✅ Internal business use
- ❌ Building competing products to HashiCorp

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform in Action (Book)](https://www.manning.com/books/terraform-in-action)
- [Oh My Zsh Terraform Plugin](https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/terraform/README.md)

## Contributing

This is a personal learning repository. Feel free to fork for your own learning journey!

## License

Code examples are for educational purposes. See book license for original material.
