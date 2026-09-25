# Security Group Rules

## `sg-alb` (attached to the ALB)

**Inbound:**

| Type | Port | Source | Reason |
|---|---|---|---|
| HTTP | 80 | `0.0.0.0/0` | Public entry point for the demo app |

**Outbound:** all traffic allowed (default) — needs to reach the app tier on port 80.

---

## `sg-app` (attached to the EC2 Auto Scaling Group instances)

**Inbound:**

| Type | Port | Source | Reason |
|---|---|---|---|
| HTTP | 80 | `sg-alb` (by security group ID) | Only the ALB can reach the app instances — no direct internet access, no SSH |

**Outbound:** all traffic allowed (default) — needed for package installs via NAT, Secrets Manager API calls, and reaching the DB tier on 3306.

> **No inbound SSH rule exists on this security group at all.** Admin
> access to these instances is via AWS Systems Manager Session Manager
> (see `docs/SETUP.md`), which needs no open inbound port.

---

## `sg-db` (attached to the RDS instance)

**Inbound:**

| Type | Port | Source | Reason |
|---|---|---|---|
| MySQL/Aurora | 3306 | `sg-app` (by security group ID) | Only app-tier instances can reach the database — not the ALB, not the internet, not even other resources in the VPC |

**Outbound:** default (irrelevant in practice — the DB subnets have no
route to the internet regardless of this rule; see `route-tables.md`).

---

## Why reference a Security Group instead of a CIDR?

Same reasoning as the VPC networking lab: referencing `sg-alb` or
`sg-app` as the source means the rule follows the *tier's identity*, not
a fixed IP range. When the Auto Scaling Group launches or terminates
instances with new IPs, or the ALB adds a node, the rules keep working
without any edits.
