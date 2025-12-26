# Chapter 2: Life Cycle of a Terraform Resource

## Core Concept

**Terraform operations are fundamentally CRUD (Create, Read, Update, Delete) operations on resources.**

In this chapter, we use the simple `local_file` resource to demonstrate how Terraform manages infrastructure through standard database-like operations. The key insight: whether you're managing a text file or a complex AWS VPC, Terraform applies the same CRUD principles.

## The Resource

`main.tf` defines a single resource containing an excerpt from Sun Tzu's "The Art of War":

```hcl
resource "local_file" "literature" {
  filename = "art_of_war.txt"
  content  = <<-EOT
    Sun Tzu said: The art of war is of vital importance to the State.

    It is a matter of life and death, a road either to safety or to ruin.
    Hence it is a subject of inquiry which can on no account be neglected.

    The art of war, then is governed by five constant factors, to be
    taken into account in one's deliberations, when seeking to
    determine the conditions obtaining in the field.

    These are: (1) The Moral Law; (2) Heaven; (3) Earth; (4) The
    Commander; (5) Method and discipline
  EOT
}
```

## Exercise Walkthrough

### 1. **CREATE** - Initial Setup

```bash
tfi  # terraform init
```

**Output:** Installed `hashicorp/local v2.5.1` provider, initialized backend.

```bash
tfp  # terraform plan
```

**Output:** Shows planned action `+ create` for `local_file.literature`

**Key observation:** Plan shows what Terraform *will* do, not what it *has* done.

```bash
tfp -out plan.out  # Save plan to file
tfsh -json plan.out > plan.json  # Export plan as JSON
cat plan.json | jq .  # Pretty-print JSON
```

**Learning:** Plans can be:
- Saved for later execution (`-out plan.out`)
- Inspected in human-readable format (`tfsh`)
- Exported as JSON for programmatic analysis

```bash
tfa "plan.out"  # terraform apply with saved plan
```

**Output:**
```
local_file.literature: Creating...
local_file.literature: Creation complete after 0s [id=de0e4d570e67f3a8102c83d933edb651a91e42db]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

**Result:** `art_of_war.txt` created with initial content (first paragraph only).

**CRUD Mapping:** This is a **CREATE** operation.

### 2. **UPDATE** - Configuration Changes

**Change made:** Edited `main.tf` to add two additional stanzas to the `content` field.

```bash
tfp  # Check what Terraform will do
```

**Output:**
```
Terraform will perform the following actions:

  # local_file.literature must be replaced
-/+ resource "local_file" "literature" {
      ~ content = <<-EOT  # forces replacement
            [shows diff with + lines for new content]
        EOT
      ~ content_sha1 = "de0e4d..." -> (known after apply)
      ~ id           = "de0e4d..." -> (known after apply)
        # (3 unchanged attributes hidden)
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

**Key observation:** Terraform plans to **replace** (destroy + create) the resource because the `content` attribute change forces replacement. The `-/+` symbol indicates this.

```bash
tfa!  # terraform apply -auto-approve
```

**Output:**
```
local_file.literature: Destroying... [id=de0e4d...]
local_file.literature: Destruction complete after 0s
local_file.literature: Creating...
local_file.literature: Creation complete after 0s [id=171f72a...]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```

**Result:** File replaced with new content including all three stanzas.

**CRUD Mapping:** This is an **UPDATE** operation, implemented as DELETE + CREATE (replacement).

### 3. **READ** - State Inspection and Refresh

```bash
tfsh  # terraform show
```

**Output:** Shows current state with all resource attributes:
```hcl
resource "local_file" "literature" {
    content              = <<-EOT
        [full content shown]
    EOT
    content_sha1         = "171f72a..."
    id                   = "171f72a..."
    filename             = "art_of_war.txt"
    # ... other computed attributes
}
```

**CRUD Mapping:** This is a **READ** operation - inspecting current state.

```bash
tf refresh  # Synchronize state with reality
```

**What happened:** Terraform reads the actual file from disk and updates the state file to match reality.

**Important:** In this session, refresh removed the resource from state (likely because the file was manually deleted or modified). This demonstrates drift detection.

```bash
tfsh  # Check state after refresh
```

**Output:** `The state file is empty. No resources are represented.`

**Learning:** `refresh` synchronizes Terraform's state with real-world infrastructure. If infrastructure is missing, state reflects that.

### 4. **DELETE** - Cleanup

```bash
tfd!  # terraform destroy -auto-approve
```

**Output:**
```
Terraform will perform the following actions:

  # local_file.literature will be destroyed
  - resource "local_file" "literature" {
      - content = <<-EOT ... EOT -> null
      - id      = "171f72a..." -> null
      # ... other attributes
    }

Plan: 0 to add, 0 to change, 1 to destroy.

local_file.literature: Destroying... [id=171f72a...]
local_file.literature: Destruction complete after 0s

Destroy complete! Resources: 1 destroyed.
```

**Result:** `art_of_war.txt` deleted, state file shows no resources.

**CRUD Mapping:** This is a **DELETE** operation.

## Key Insights

### Terraform Operations Map to CRUD

| Terraform Command    | CRUD Operation | What It Does                                    |
|---------------------|----------------|-------------------------------------------------|
| `terraform apply`    | **CREATE**     | Creates resources that don't exist              |
| `terraform refresh`  | **READ**       | Reads current state from real infrastructure    |
| `terraform apply`    | **UPDATE**     | Updates/replaces resources when config changes  |
| `terraform destroy`  | **DELETE**     | Deletes all managed resources                   |

### Configuration is the Source of Truth

- **Desired state** lives in `.tf` files
- **Actual state** is tracked in `terraform.tfstate`
- **Plan** shows the diff between desired and actual
- **Apply** reconciles actual with desired

### Resource Replacement vs In-Place Update

Some attribute changes require **replacement** (destroy + create):
- `local_file.content` cannot be updated in-place
- Terraform destroys old file, creates new one
- Indicated by `-/+` in plan output

Other resources support **in-place updates** (indicated by `~` in plan).

### State Management

The `terraform.tfstate` file is critical:
- Records what Terraform has created
- Used to calculate diffs during `plan`
- Can drift from reality if infrastructure is manually changed
- `refresh` synchronizes state with reality

### Configuration Drift

**Scenario (mentioned but not shown in session):** Manually edit `art_of_war.txt` and change `"Sun Tzu"` to `"Napoleon"`.

**What would happen:**
1. `terraform refresh` detects the change
2. `terraform plan` shows Terraform wants to restore original content
3. `terraform apply` overwrites manual change

**Lesson:** All changes should go through Terraform configuration, not manual edits.

## Debugging and Logging

Terraform supports multiple log levels via `TF_LOG` environment variable:

```bash
TF_LOG=DEBUG tfp  # Maximum verbosity - shows provider plugin communication
TF_LOG=INFO tfp   # Moderate verbosity - shows major operations
TF_LOG=TRACE tfp  # Even more detailed than DEBUG
```

**From the session:**
- DEBUG logs show provider plugin startup, RPC communication, graph building
- INFO logs show high-level operations (init, plan, apply)
- Useful for troubleshooting provider issues

## Terraform Aliases Reference

Aliases used in this exercise (typically defined in `~/.oh-my-zsh` or shell config):

| Alias  | Full Command                    | Description                                      |
|--------|---------------------------------|--------------------------------------------------|
| `tf`   | `terraform`                     | Base Terraform CLI                               |
| `tfi`  | `terraform init`                | Initialize working directory & download providers|
| `tfp`  | `terraform plan`                | Preview changes without applying                 |
| `tfa`  | `terraform apply`               | Apply changes (prompts for confirmation)         |
| `tfa!` | `terraform apply -auto-approve` | Apply changes without confirmation prompt        |
| `tfd`  | `terraform destroy`             | Destroy all resources (prompts for confirmation) |
| `tfd!` | `terraform destroy -auto-approve`| Destroy without confirmation                    |
| `tfsh` | `terraform show`                | Display current state or saved plan              |
| `tff`  | `terraform fmt`                 | Format `.tf` files to canonical style            |
| `tfv`  | `terraform validate`            | Validate configuration syntax                    |

**Note:** The `!` suffix typically maps to `-auto-approve` flag, skipping interactive confirmation.

## Plan Output Formats

```bash
# Human-readable plan
tfp

# Save plan for later
tfp -out plan.out

# Show saved plan
tfsh plan.out

# Export plan as JSON
tfsh -json plan.out > plan.json

# Pretty-print JSON with jq
cat plan.json | jq .
```

**Use cases:**
- **Saved plans:** CI/CD pipelines (plan in CI, apply in CD)
- **JSON export:** Automated policy checking, cost estimation, audit logs
- **Human-readable:** Code reviews, documentation

## Next Steps

**Chapter 3** will introduce:
- **Variables** for parameterizing configurations
- **Outputs** for extracting computed values
- **State management** patterns for team collaboration

**Key Takeaway:** Terraform is a state management engine that performs CRUD operations to reconcile desired state (configuration) with actual state (infrastructure). Whether you're managing files, VMs, or entire cloud environments, the principles remain the same.
