# Chapter 3: Variables, Locals, Functions, and Multiple Resources

## Core Concept

**Terraform configurations become reusable and maintainable through variables, locals, built-in functions, and meta-arguments like `count`.**

This chapter demonstrates how to:

- Accept structured input via **variables** with validation
- Transform data with **locals** and built-in functions
- Create multiple similar resources using the **count** meta-argument
- Generate dynamic content with the **templatefile()** function
- Orchestrate resource dependencies with **depends_on**

The exercise builds a "Mad Libs" generator that creates 100 randomized text files and packages them into a ZIP archive.

## Project Structure

```
chapter_03/
├── madlibs.tf           # Main configuration with variables, resources, and data sources
├── terraform.tfvars     # Input values for the word pool
├── templates/           # Mad Libs story templates with placeholders
│   ├── alice.txt
│   ├── photographer.txt
│   └── observatory.txt
└── madlibs/             # Generated files (created by Terraform, gitignored)
    ├── madlibs-0.txt
    ├── madlibs-1.txt
    └── ... (100 files total)
```

## The Configuration

### 1. Variables - Structured Input with Validation

```hcl
variable "words" {
  description = "A word pool to use for Mad libs"
  type = object({
    nouns      = list(string),
    adjectives = list(string),
    verbs      = list(string),
    adverbs    = list(string),
    numbers    = list(number),
  })

  validation {
    condition     = length(var.words["nouns"]) >= 10
    error_message = "At least 10 nouns must be supplied"
  }
}

variable "num_files" {
  type    = number
  default = 100
}
```

**Key Features:**

- **Complex type:** `object` with nested `list()` types for structured data
- **Validation:** Enforces business rules (minimum 10 nouns)
- **Default values:** `num_files` has a sensible default
- **Type safety:** Terraform validates types before execution

**Supplied via `terraform.tfvars`:**

```hcl
words = {
  nouns = ["army", "panther", "walnuts", "sandwich", "apples", "banana",
           "cat", "jellyfish", "jigsaw", "violin", "milk", "sun"]
  adjectives = ["bitter", "sticky", "thundering", "abundant", "chubby", "grumpy"]
  verbs      = ["run", "dance", "love", "respect", "kicked", "baked"]
  adverbs    = ["delicately", "beautifully", "quickly", "truthfully", "wearily"]
  numbers    = [42, 27, 101, 73, -5, 0]
}
```

### 2. Locals - Data Transformation

```hcl
locals {
  uppercase_words = { for k, v in var.words : k => [for s in v : upper(s)] }
  templates       = tolist(fileset(path.module, "templates/*.txt"))
}
```

**What's Happening:**

- **`uppercase_words`:** Uses a **for expression** to transform all words to uppercase
  - Outer loop: iterates over map keys (`nouns`, `adjectives`, etc.)
  - Inner loop: transforms each string in the list with `upper()`
  - Result: Same structure as `var.words`, but all uppercase
- **`templates`:** Uses `fileset()` to discover all `.txt` files in `templates/` directory
  - Returns a set, converted to list with `tolist()`
  - Enables dynamic template discovery without hardcoding filenames

**Why Locals?**

- Avoids repeating complex expressions
- Makes configuration DRY (Don't Repeat Yourself)
- Computed values that don't need to be exposed as variables

### 3. Count - Multiple Resource Instances

```hcl
resource "random_shuffle" "random_nouns" {
  count = var.num_files
  input = local.uppercase_words["nouns"]
}

resource "random_shuffle" "random_adjectives" {
  count = var.num_files
  input = local.uppercase_words["adjectives"]
}
# ... (similar for verbs, adverbs, numbers)
```

**Key Points:**

- **`count` creates 100 instances** of each resource type (one per Mad Lib file)
- Each instance is indexed: `random_shuffle.random_nouns[0]`, `random_shuffle.random_nouns[1]`, etc.
- The `random_shuffle` resource randomizes the order of input list
- Result: Each Mad Lib gets differently ordered word lists

### 4. Template Rendering with `templatefile()`

**Template Example (`templates/alice.txt`):**

```text
ALICE'S UPSIDE-DOWN WORLD

Lewis Carroll's classic, "Alice's Adventures in Wonderland", as well
as its ${adjectives[0]} sequel, "Through the Looking ${nouns[0]}",
have enchanted both the young and old ${nouns[1]}s for the last
${numbers[0]} years...
```

**Resource Using Template:**

```hcl
resource "local_file" "mad_libs" {
  count    = var.num_files
  filename = "madlibs/madlibs-${count.index}.txt"
  content = templatefile(element(local.templates, count.index),
    {
      nouns      = random_shuffle.random_nouns[count.index].result
      adjectives = random_shuffle.random_adjectives[count.index].result
      verbs      = random_shuffle.random_verbs[count.index].result
      adverbs    = random_shuffle.random_adverbs[count.index].result
      numbers    = random_shuffle.random_numbers[count.index].result
  })
}
```

**How It Works:**

1. **`count.index`:** Special variable available inside `count` resources (0-99)
2. **`element(list, index)`:** Cycles through templates (wraps around if index > list length)
3. **`templatefile(path, vars)`:** Renders template with variable substitutions
4. **Dependency:** Each file depends on corresponding `random_shuffle` resources

**Result:** 100 files, each with randomized words filling in template placeholders.

### 5. Archive Creation with Explicit Dependency

```hcl
data "archive_file" "mad_libs" {
  depends_on  = [local_file.mad_libs]
  source_dir  = "${path.module}/madlibs"
  output_path = "${path.cwd}/madlibs.zip"
  type        = "zip"
}
```

**Key Features:**

- **`data` source:** Reads/computes data rather than creating infrastructure
- **`depends_on`:** Explicit dependency ensures all 100 files are created first
- **`path.module`:** Directory containing current module
- **`path.cwd`:** Current working directory
- **Result:** Single `madlibs.zip` containing all generated files

## Exercise Walkthrough

### 1. Initialize and Validate

```bash
tfiu  # terraform init -upgrade
```

**Output:**

```
Initializing provider plugins...
- Finding hashicorp/local versions matching "~> 2.5"...
- Installing hashicorp/local v2.6.1...
- Installed hashicorp/local v2.6.1 (signed by HashiCorp)

Terraform has been successfully initialized!
```

**Providers Installed:**

- `hashicorp/random` v3.7.2 - For shuffling word lists
- `hashicorp/local` v2.6.1 - For creating text files
- `hashicorp/archive` v2.7.1 - For creating ZIP archive

```bash
tfv  # terraform validate
```

**Output:**

```
Success! The configuration is valid.
```

**Validation Checks:**

- Syntax is correct
- Variable types match declarations
- All required variables have values (from `terraform.tfvars`)
- Variable validation rules pass (at least 10 nouns)

### 2. Apply Configuration

```bash
tfa!  # terraform apply -auto-approve
```

**What Happens:**

1. **Creates 500 `random_shuffle` resources** (100 × 5 word types)
   - Each shuffles its input list into random order
2. **Creates 100 `local_file` resources**
   - Each renders a template with randomized words
   - Cycles through 3 templates (alice, photographer, observatory)
3. **Creates 1 `archive_file` data source**
   - Waits for all files to be created
   - Packages all 100 files into `madlibs.zip`

**Expected Output:**

```
Apply complete! Resources: 601 added, 0 changed, 0 destroyed.
```

**Result on Disk:**

```
madlibs/
├── madlibs-0.txt
├── madlibs-1.txt
├── ...
└── madlibs-99.txt

madlibs.zip  (contains all 100 files)
```

### 3. Verify the Output

```bash
unzip -v madlibs.zip | head -n 10
```

**Output:**

```
Archive:  madlibs.zip
 Length   Method    Size  Cmpr    Date    Time   CRC-32   Name
--------  ------  ------- ---- ---------- ----- --------  ----
     719  Defl:N      470  35% 01-01-2049 00:00 fc244b2b  madlibs-0.txt
     584  Defl:N      385  34% 01-01-2049 00:00 f6b71e21  madlibs-1.txt
     586  Defl:N      389  34% 01-01-2049 00:00 8b726821  madlibs-10.txt
     524  Defl:N      353  33% 01-01-2049 00:00 1e678531  madlibs-11.txt
     725  Defl:N      476  34% 01-01-2049 00:00 510a9089  madlibs-12.txt
     587  Defl:N      389  34% 01-01-2049 00:00 3230ac0b  madlibs-13.txt
     521  Defl:N      350  33% 01-01-2049 00:00 083b0419  madlibs-14.txt
```

**Success Indicators:**

- 100 files present in archive
- Files have varying sizes (different templates/content)
- Compression working (Size < Length)

**Sample Generated Content:**

```
ALICE'S UPSIDE-DOWN WORLD

Lewis Carroll's classic, "Alice's Adventures in Wonderland", as well
as its STICKY sequel, "Through the Looking BANANA", have enchanted
both the young and old PANTHERs for the last 42 years...
```

### 4. Cleanup

```bash
tfd!  # terraform destroy -auto-approve
```

**Output:**

```
Destroy complete! Resources: 601 destroyed.
```

**What Gets Deleted:**

- All 100 `madlibs/*.txt` files
- The `madlibs/` directory
- The `madlibs.zip` archive
- All `random_shuffle` resource state
- All `local_file` resource state

**What Remains:**

- `.tf` configuration files
- `terraform.tfvars`
- `templates/*.txt` (source templates)
- `terraform.tfstate` (records that everything is deleted)

## Key Insights

### Variables Enable Reusability

**Without variables:**

```hcl
resource "local_file" "example" {
  content = "Hello, World!"  # Hardcoded
}
```

**With variables:**

```hcl
variable "greeting" {
  type = string
}

resource "local_file" "example" {
  content = var.greeting  # Parameterized
}
```

**Benefits:**

- Same configuration works for different inputs
- Easy to test (different `.tfvars` files for dev/staging/prod)
- Validation ensures data quality

### Variable Types and Validation

| Type            | Example         | Use Case                        |
| --------------- | --------------- | ------------------------------- |
| `string`        | `"hello"`       | Filenames, names, simple values |
| `number`        | `42`            | Counts, sizes, ports            |
| `bool`          | `true`          | Feature flags, enable/disable   |
| `list(string)`  | `["a", "b"]`    | Multiple similar values         |
| `map(string)`   | `{key = "val"}` | Key-value configuration         |
| `object({...})` | Structured data | Complex nested configuration    |

**Validation Example:**

```hcl
validation {
  condition     = length(var.words["nouns"]) >= 10
  error_message = "At least 10 nouns must be supplied"
}
```

**Why Validate?**

- Catch errors early (before API calls to cloud providers)
- Enforce business rules
- Provide clear error messages

### Locals vs Variables

| Feature         | Variables                  | Locals                               |
| --------------- | -------------------------- | ------------------------------------ |
| **Input**       | User-supplied              | Computed from other values           |
| **Validation**  | Yes                        | No (but can use precondition blocks) |
| **DRY**         | For external configuration | For internal expression reuse        |
| **When to use** | Parameterize config        | Transform data, avoid repetition     |

**Example:**

```hcl
# Variable: user supplies this
variable "environment" {
  type = string
}

# Local: computed from variable + logic
locals {
  name_prefix = "${var.environment}-myapp"
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

### The `count` Meta-Argument

**Creates multiple instances of a resource:**

```hcl
resource "aws_instance" "web" {
  count = 3
  # Creates: aws_instance.web[0], aws_instance.web[1], aws_instance.web[2]
}
```

**Referencing instances:**

```hcl
# Single instance
resource.type.name.attribute

# With count
resource.type.name[0].attribute
resource.type.name[count.index].attribute  # Inside count block
```

**When NOT to use `count`:**

- If instances need different configurations (use `for_each` instead)
- If order matters and items might be removed from middle (causes recreation)

### Built-in Functions

Terraform has 100+ built-in functions. Key ones from this chapter:

| Function                   | Purpose              | Example                                |
| -------------------------- | -------------------- | -------------------------------------- |
| `upper(string)`            | Convert to uppercase | `upper("hello")` → `"HELLO"`           |
| `length(list)`             | Count items          | `length([1,2,3])` → `3`                |
| `element(list, index)`     | Get item (wraps)     | `element([1,2], 5)` → `2`              |
| `fileset(path, pattern)`   | Find files           | `fileset(".", "*.txt")` → set of files |
| `tolist(set)`              | Convert set to list  | `tolist(fileset(...))`                 |
| `templatefile(path, vars)` | Render template      | See template example above             |

**Documentation:** [Terraform Functions Reference](https://developer.hashicorp.com/terraform/language/functions)

### For Expressions

**List transformation:**

```hcl
[for s in var.list : upper(s)]
# Input:  ["a", "b", "c"]
# Output: ["A", "B", "C"]
```

**Map transformation:**

```hcl
{for k, v in var.map : k => upper(v)}
# Input:  {name = "alice", city = "nyc"}
# Output: {name = "ALICE", city = "NYC"}
```

**Nested iteration (from this chapter):**

```hcl
{ for k, v in var.words : k => [for s in v : upper(s)] }
# Input:  {nouns = ["cat", "dog"], verbs = ["run", "jump"]}
# Output: {nouns = ["CAT", "DOG"], verbs = ["RUN", "JUMP"]}
```

### Template Files

**Pattern:**

```hcl
# Template file: greeting.tpl
Hello, ${name}! You are ${age} years old.

# Terraform code:
templatefile("greeting.tpl", {
  name = "Alice"
  age  = 30
})

# Result:
# "Hello, Alice! You are 30 years old."
```

**Advanced - accessing list items in templates:**

```hcl
${adjectives[0]}  # First adjective
${nouns[2]}       # Third noun
```

**Use cases:**

- User data scripts for EC2 instances
- Configuration files (nginx.conf, etc.)
- HTML/email templates
- Any text file with dynamic content

### Explicit Dependencies with `depends_on`

**Terraform auto-detects dependencies:**

```hcl
resource "aws_instance" "web" {
  subnet_id = aws_subnet.main.id  # Implicit dependency
}
```

**Sometimes you need explicit dependencies:**

```hcl
data "archive_file" "mad_libs" {
  depends_on = [local_file.mad_libs]  # Explicit dependency
  source_dir = "${path.module}/madlibs"
  # ...
}
```

**Why explicit here?**

- Archive reads from filesystem, not Terraform attributes
- Terraform can't auto-detect that archive needs files to exist first
- `depends_on` forces correct ordering

**When to use `depends_on`:**

- Side effects not visible in resource attributes
- Ensuring order when auto-detection fails
- Workarounds for provider bugs

**Warning:** Overuse makes plans slower. Prefer implicit dependencies when possible.

### Data Sources vs Resources

|             | Resource                        | Data Source               |
| ----------- | ------------------------------- | ------------------------- |
| **Keyword** | `resource`                      | `data`                    |
| **Purpose** | Create/manage infrastructure    | Read existing data        |
| **State**   | Tracked and managed             | Read-only                 |
| **Example** | `resource "aws_instance" "web"` | `data "aws_ami" "ubuntu"` |

**From this chapter:**

```hcl
# Resource: Creates files
resource "local_file" "mad_libs" { ... }

# Data source: Reads files and creates archive
data "archive_file" "mad_libs" { ... }
```

**Common data sources:**

- `data "aws_ami"` - Find latest AMI
- `data "aws_availability_zones"` - List AZs in region
- `data "terraform_remote_state"` - Read another workspace's outputs
- `data "archive_file"` - Create ZIP/TAR from files

## Production Patterns

### Variable File Organization

**For learning (this repo):**

```
chapter_03/
├── madlibs.tf
└── terraform.tfvars  # All variables in one file
```

**For production:**

```
infrastructure/
├── variables.tf       # Variable declarations only
├── main.tf            # Resource definitions
├── outputs.tf         # Output declarations
├── terraform.tfvars   # Non-sensitive defaults (checked in)
└── secrets.tfvars     # Sensitive values (gitignored, in 1Password/Vault)
```

**Apply with:**

```bash
terraform apply -var-file=terraform.tfvars -var-file=secrets.tfvars
```

### Environment-Specific Configurations

**Pattern 1: Separate .tfvars files**

```
├── dev.tfvars
├── staging.tfvars
└── prod.tfvars

# Usage:
terraform apply -var-file=prod.tfvars
```

**Pattern 2: Separate directories**

```
├── modules/           # Reusable modules
│   └── app/
├── environments/
│   ├── dev/
│   │   └── main.tf   # Uses ../modules/app
│   ├── staging/
│   │   └── main.tf
│   └── prod/
│       └── main.tf
```

### Validation Best Practices

```hcl
variable "instance_type" {
  type = string

  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium"
    ], var.instance_type)
    error_message = "Instance type must be t3.micro, t3.small, or t3.medium"
  }
}

variable "environment" {
  type = string

  validation {
    condition = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod"
  }
}
```

**Why validate?**

- Prevent typos (`prodction` instead of `production`)
- Enforce naming conventions
- Catch misconfigurations before expensive API calls

## Common Pitfalls

### 1. Count Index Shift

**Problem:**

```hcl
resource "aws_instance" "web" {
  count = 3
  # Creates: web[0], web[1], web[2]
}

# Later, remove first instance by changing count to 2
# Terraform DESTROYS web[2] and RECREATES web[1]!
```

**Why?** Count uses numeric indices. Removing from middle causes shift.

**Solution:** Use `for_each` with map/set for stable identifiers:

```hcl
resource "aws_instance" "web" {
  for_each = toset(["web1", "web2", "web3"])
  # Creates: web["web1"], web["web2"], web["web3"]
  # Removing "web1" only destroys that instance
}
```

### 2. Variable Type Mismatches

**Error:**

```hcl
variable "ports" {
  type = list(number)
}

# In terraform.tfvars:
ports = ["80", "443"]  # ERROR: strings, not numbers
```

**Fix:**

```hcl
ports = [80, 443]  # Correct: numbers
```

### 3. Circular Dependencies

**Problem:**

```hcl
resource "a" "example" {
  value = b.example.output
}

resource "b" "example" {
  value = a.example.output
}
# ERROR: Cycle in dependency graph
```

**Fix:** Rethink architecture - one resource should come first.

## Terraform Aliases Reference

From the exercise (Oh My Zsh terraform plugin):

| Alias  | Full Command                      | Description                             |
| ------ | --------------------------------- | --------------------------------------- |
| `tfiu` | `terraform init -upgrade`         | Initialize and upgrade providers        |
| `tfv`  | `terraform validate`              | Validate configuration syntax           |
| `tfa!` | `terraform apply -auto-approve`   | Apply without confirmation              |
| `tfd!` | `terraform destroy -auto-approve` | Destroy without confirmation            |
| `gst`  | `git status`                      | Check git status (Oh My Zsh git plugin) |

## Further Reading

- [Input Variables Documentation](https://developer.hashicorp.com/terraform/language/values/variables)
- [Local Values Documentation](https://developer.hashicorp.com/terraform/language/values/locals)
- [Functions Reference](https://developer.hashicorp.com/terraform/language/functions)
- [The `count` Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Template Files](https://developer.hashicorp.com/terraform/language/functions/templatefile)

---

**Exercise Summary:**

- **Resources Created:** 601 (500 random_shuffle + 100 local_file + 1 archive_file)
- **Lines of Terraform:** ~82
- **Lines of Output:** 100 Mad Libs files + 1 ZIP archive
- **AWS Cost:** $0.00
- **Key Learning:** Variables and functions make Terraform configurations powerful and reusable
