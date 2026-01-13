# Chapter 6: Team Workflows with Remote State

## Overview

This chapter explores Terraform team collaboration patterns and remote state management. While the book "Terraform in Action" focuses on using **S3 + DynamoDB for state locking**, this implementation uses a **Spacelift-based approach** that eliminates the need for distributed locking.

## Architectural Decision: Spacelift vs. DynamoDB Locking

### The Book's Approach (S3 + DynamoDB)

```
┌─────────────┐         ┌─────────────┐
│  Developer  │         │  Developer  │
│      A      │         │      B      │
└──────┬──────┘         └──────┬──────┘
       │                       │
       │  terraform apply      │  terraform apply
       │                       │
       v                       v
┌──────────────────────────────────────┐
│     DynamoDB Lock Table              │
│  (Pessimistic Concurrency Control)   │
│                                      │
│  ⚠️  Lock contention                 │
│  ⚠️  Orphaned locks                  │
│  ⚠️  Manual force-unlock             │
└──────────────────────────────────────┘
       │
       v
┌──────────────────────────────────────┐
│        S3 State Storage              │
└──────────────────────────────────────┘
```

**Characteristics:**
- **CP model** (Consistency + Partition tolerance)
- Distributed locking with lock contention
- Blocks concurrent operations on same workspace
- Requires manual intervention for orphaned locks
- Direct `terraform` CLI execution

### Our Approach (Spacelift + S3)

```
┌─────────────┐         ┌─────────────┐
│  Developer  │         │  Developer  │
│      A      │         │      B      │
└──────┬──────┘         └──────┬──────┘
       │                       │
       │  git push             │  git push
       │                       │
       v                       v
┌──────────────────────────────────────┐
│          GitHub Repository           │
└──────────────┬───────────────────────┘
               │ webhook
               v
┌──────────────────────────────────────┐
│        Spacelift Orchestrator        │
│   (Queue-Based Actor Model)          │
│                                      │
│  ✅ Sequential execution per Stack   │
│  ✅ No lock contention               │
│  ✅ Automatic retry on failure       │
│  ✅ PR-triggered plans               │
└──────────────┬───────────────────────┘
               │
               v
┌──────────────────────────────────────┐
│        S3 State Storage              │
└──────────────────────────────────────┘
```

**Characteristics:**
- **AP model** (Availability + Partition tolerance with eventual consistency)
- Queue-based execution (actor mailbox pattern)
- No distributed locks needed
- Single writer per workspace (the Spacelift agent)
- PR-driven workflow with plan previews

## Actor Model Analogy

For developers familiar with Akka or message-passing systems:

| Actor Model Concept | Spacelift Equivalent |
|---------------------|----------------------|
| Actor               | Stack (workspace)    |
| Mailbox             | Run queue            |
| Message             | Terraform run (plan/apply) |
| Supervisor          | Spacelift orchestrator |
| Sequential processing | Runs execute one at a time per Stack |
| Parallel actors     | Multiple Stacks can run simultaneously |

**Key insight:** Each Stack is an actor with a mailbox (run queue). Commands are enqueued and processed sequentially. No locks needed because there's a single writer per Stack.

## Trade-Offs

| Aspect | DynamoDB Locking | Spacelift |
|--------|------------------|-----------|
| **Cost** | ~$0.50/month (DynamoDB) | Free tier: 2 users, unlimited Stacks |
| **Setup Complexity** | Low (1 table + S3 bucket) | Medium (GitHub app, account setup) |
| **Lock Contention** | Yes (explicit locks) | No (queue-based) |
| **Orphaned Locks** | Possible (manual unlock) | Not applicable |
| **Concurrent Applies** | Blocked by lock | Queued, execute sequentially |
| **PR Integration** | Manual (or custom CI) | Built-in (plan on PR) |
| **Audit Trail** | CloudTrail logs | Built-in run history |
| **Policy Enforcement** | External tools | Built-in policies (OPA, Sentinel) |
| **CLI Workflow** | Direct `terraform` | Via Spacelift API or UI |

## When to Use Each Approach

### Use DynamoDB Locking When:
- You want minimal external dependencies
- Team uses direct `terraform` CLI workflow
- You're on a tight budget (AWS credits, free tier S3/DynamoDB)
- You don't need advanced workflow features
- You prefer simplicity over features

### Use Spacelift (or similar) When:
- You want PR-driven workflows
- You need policy-as-code enforcement
- You want built-in audit trails
- You need role-based access control (RBAC)
- You're managing multiple teams/environments
- You want to avoid distributed locking complexity

### Other Options
- **Terraform Cloud:** HashiCorp's managed offering (similar to Spacelift)
- **Atlantis:** Self-hosted PR automation (middle ground)
- **GitLab/GitHub CI + S3/DynamoDB:** DIY approach

## Repository Structure

```
chapter_06/
├── README.md                    # This file
├── modules/
│   └── s3-backend/              # Reusable S3 backend module
│       ├── main.tf              # S3 bucket for state storage
│       ├── variables.tf         # Input variables
│       ├── outputs.tf           # Bucket name, region, etc.
│       └── README.md            # Module documentation
├── backend-bootstrap/           # One-time setup (creates S3 bucket)
│   ├── main.tf                  # Uses LOCAL state (chicken-egg problem)
│   ├── outputs.tf               # Outputs bucket name for workspaces
│   └── terraform.tfstate        # ⚠️ COMMITTED (exception to rule)
├── workspaces/
│   ├── dev/                     # Dev environment
│   │   ├── main.tf              # Example infrastructure
│   │   ├── backend.tf           # S3 backend configuration
│   │   └── variables.tf
│   └── prod/                    # Prod environment
│       ├── main.tf              # Example infrastructure
│       ├── backend.tf           # S3 backend configuration
│       └── variables.tf
└── .spacelift/                  # Spacelift configuration (optional)
    └── config.yml               # Stack configuration as code
```

## Implementation Steps

### Phase 1: Bootstrap S3 Backend
1. Create S3 bucket for state storage (using local state)
2. Enable versioning and encryption
3. Output bucket details for workspace configuration

### Phase 2: Create Workspaces
1. Dev workspace with simple infrastructure (e.g., S3 bucket or EC2)
2. Prod workspace with similar infrastructure
3. Each configured to use remote S3 backend with different state keys

### Phase 3: Spacelift Setup
1. Connect GitHub repository to Spacelift
2. Create Stack for dev workspace
3. Create Stack for prod workspace
4. Configure triggers (PR-based or push-based)

### Phase 4: Test Workflow
1. Make change to dev workspace via PR
2. Observe Spacelift plan result
3. Merge PR and observe apply
4. Make change to prod workspace
5. Verify state isolation between workspaces

## Key Concepts from Chapter 6 (Still Apply)

Even though we're using Spacelift, these concepts from the book remain important:

1. **Remote State Storage:** S3 stores state files (Spacelift orchestrates access)
2. **State Isolation:** Separate state files per environment (dev vs prod)
3. **Backend Configuration:** Each workspace configures S3 backend
4. **Output Sharing:** Use `terraform_remote_state` data source to share outputs between workspaces
5. **Module Publishing:** Reusable modules (s3-backend) accessible across workspaces

## Cost Considerations

**S3 State Storage:**
- State files are tiny (few KB to few MB)
- S3 free tier: 5GB storage, 20,000 GET requests/month
- **Estimated cost:** < $0.10/month for state storage

**Spacelift:**
- Free tier: 2 users, unlimited Stacks, 500 tracked resources
- **Estimated cost:** $0 for this learning exercise

**Infrastructure Resources (dev/prod):**
- Using minimal resources (t3.micro, small S3 buckets)
- **Estimated cost:** < $5/month if left running
- **Strategy:** Destroy immediately after testing

**Total:** < $5/month, free if cleaned up daily

## Success Criteria

By the end of this chapter, you'll understand:
- ✅ Remote state storage with S3
- ✅ State isolation between environments
- ✅ Team collaboration patterns
- ✅ Queue-based vs lock-based concurrency control
- ✅ PR-driven infrastructure workflows
- ✅ The trade-offs between different backend approaches

## Distributed Systems Perspective

From a distributed systems lens, this chapter explores:

**Concurrency Control:**
- **Pessimistic (DynamoDB locks):** Assume conflicts, prevent concurrent writes
- **Optimistic (Spacelift queues):** Assume no conflicts, serialize via single writer

**Consistency Models:**
- **DynamoDB approach:** Strong consistency via locking (CP system)
- **Spacelift approach:** Eventual consistency with queue ordering (AP system)

**Fault Tolerance:**
- **DynamoDB:** Lock timeout + manual recovery
- **Spacelift:** Automatic retry + run history

**Actor Model:**
- Each Stack = actor with mailbox
- Messages = Terraform runs
- Sequential processing per actor
- Parallel execution across actors

This mirrors patterns you've seen in Akka, Erlang/OTP, and message queue systems.

## References

- [Terraform in Action](https://www.manning.com/books/terraform-in-action) - Chapter 6
- [Spacelift Documentation](https://docs.spacelift.io/)
- [Terraform Backend: S3](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [Actor Model](https://en.wikipedia.org/wiki/Actor_model)

---

**Next Steps:** Proceed to `backend-bootstrap/` to create the S3 bucket for state storage.
