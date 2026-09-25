# AWS Three-Tier Web App (ALB + EC2 Auto Scaling + RDS Multi-AZ)

A classic highly-available three-tier web architecture on AWS: a public
load-balanced web tier, an auto-scaling application tier in private
subnets, and a Multi-AZ managed database — each tier isolated from the
others by network and security group design, not just by naming.

## 🏗️ Architecture

```
                                Internet
                                    │
                                    ▼
                          ┌──────────────────┐
                          │  Internet Gateway  │
                          └─────────┬──────────┘
                                    │
   VPC: 10.1.0.0/16                │
  ┌──────────────────────────────────┴──────────────────────────────────┐
  │                                                                      │
  │   AZ-a                                    AZ-b                      │
  │  ┌─────────────────────┐               ┌─────────────────────┐     │
  │  │ Public Subnet         │               │ Public Subnet         │     │
  │  │ 10.1.0.0/24            │               │ 10.1.1.0/24            │     │
  │  │   [ALB node]  ◀────────┼───────────────┼──▶ [ALB node]         │     │
  │  │   [NAT Gateway]        │               │                        │     │
  │  └───────────┬─────────┘               └───────────┬─────────┘     │
  │              │  Tier 1: Web/Routing                 │               │
  │              ▼                                       ▼               │
  │  ┌─────────────────────┐               ┌─────────────────────┐     │
  │  │ App Subnet (private)  │               │ App Subnet (private)  │     │
  │  │ 10.1.10.0/24           │               │ 10.1.11.0/24           │     │
  │  │  [EC2 - ASG, PHP app]  │               │  [EC2 - ASG, PHP app]  │     │
  │  └───────────┬─────────┘               └───────────┬─────────┘     │
  │              │  Tier 2: Application                 │               │
  │              ▼                                       ▼               │
  │  ┌─────────────────────┐               ┌─────────────────────┐     │
  │  │ DB Subnet (isolated)  │               │ DB Subnet (isolated)  │     │
  │  │ 10.1.20.0/24           │               │ 10.1.21.0/24           │     │
  │  │  [RDS MySQL - Primary] │◀── sync ────▶│  [RDS MySQL - Standby] │     │
  │  └─────────────────────┘               └─────────────────────┘     │
  │                                    Tier 3: Data (Multi-AZ)          │
  └──────────────────────────────────────────────────────────────────────┘
```

## 🎯 Design Decisions

| Decision | Reason |
|---|---|
| Fresh, standalone VPC (`10.1.0.0/16`) | Keeps this project fully independent of the [VPC networking lab](../02-vpc-networking-lab) — different CIDR range avoids any confusion if both are ever peered later |
| 3 tiers × 2 AZs = 6 subnets | Every tier is HA-capable from day one — no single-AZ dependency anywhere |
| DB subnets have **no route to the internet at all** | Not even via NAT — the data tier has zero outbound path, the strictest isolation of the three tiers |
| No SSH / no bastion host | App instances are managed via **AWS Systems Manager Session Manager** instead — no open port 22 anywhere in this architecture, no key pairs to lose track of |
| RDS-managed master password (Secrets Manager) | Enabled at RDS creation time — AWS rotates and stores the credential, the app fetches it at boot instead of it ever being hardcoded |
| Security groups reference each other, not CIDRs | `sg-app` only accepts traffic from `sg-alb`'s ID; `sg-db` only accepts traffic from `sg-app`'s ID — same pattern as the VPC lab, extended across three tiers |
| Single NAT Gateway | Cost-conscious choice for a portfolio project — only the app tier needs outbound (for package installs, SSM agent, Secrets Manager calls); documented trade-off same as the VPC lab |
| Launch Template (not Launch Configuration) | Launch Configurations are the legacy, AWS no longer recommends them for new Auto Scaling Groups |

## 🛠️ AWS Services Used

- **Amazon VPC** — 6 subnets across 2 AZs (public / app / db)
- **Internet Gateway + NAT Gateway** — public tier internet access, app tier outbound-only
- **Application Load Balancer (ALB)** — public entry point, health checks, distributes to the ASG
- **EC2 Auto Scaling Group + Launch Template** — application tier, scales on ALB request count
- **Amazon RDS for MySQL (Multi-AZ)** — managed database with automatic failover
- **AWS Secrets Manager** — RDS-managed master credential, fetched by the app at boot
- **AWS Systems Manager (Session Manager)** — admin access to app instances, no SSH/bastion needed
- **Security Groups** — three tiers, each scoped to only the tier in front of it
- **IAM** — EC2 instance role scoped to exactly one secret + SSM + CloudWatch Logs
- **CloudWatch** — ASG scaling alarms, ALB target health, RDS metrics

## 📁 Repo Structure

```
aws-three-tier-web-app/
├── README.md                        ← you are here
├── docs/
│   └── SETUP.md                     ← step-by-step console build guide
├── configs/
│   ├── cidr-plan.md                 ← subnet/CIDR reference table
│   ├── security-groups.md           ← SG rules reference table
│   └── route-tables.md              ← route table reference
├── policies/
│   └── ec2-instance-role-policy.json ← least-privilege IAM policy for app instances
├── app/
│   ├── index.php                    ← demo homepage (shows instance ID + DB connection status)
│   └── config.php.template          ← DB config template (populated by user-data at boot)
└── scripts/
    ├── user-data.sh                 ← EC2 Launch Template bootstrap script
    └── test-app.sh                  ← validates ALB routing + DB connectivity from outside
```

## 🚀 Quick Start

1. Follow [`docs/SETUP.md`](docs/SETUP.md) — builds the VPC, all 6 subnets, IGW, NAT Gateway, route tables, security groups, RDS, the Launch Template + ASG, and the ALB, in order.
2. Reference [`configs/cidr-plan.md`](configs/cidr-plan.md) and [`configs/security-groups.md`](configs/security-groups.md) while building so every value matches.
3. Paste [`scripts/user-data.sh`](scripts/user-data.sh) into the Launch Template's user data field (after filling in the placeholders).
4. Once the ALB is active and the ASG has healthy targets, run:
   ```bash
   chmod +x scripts/test-app.sh
   ./scripts/test-app.sh
   ```
5. Visit the ALB's DNS name in a browser — you should see the demo homepage confirming a live DB connection.

## ✅ What This Proves

- Web tier (ALB) is the only internet-facing component
- App tier is only reachable from the ALB, has no SSH exposure, and can still be administered via SSM
- DB tier is reachable **only** from the app tier, has automatic Multi-AZ failover, and has no internet route whatsoever
- Credentials are never hardcoded — fetched from Secrets Manager at instance boot

## 💰 Cost Notes

The most expensive pieces here are the **NAT Gateway** (hourly + per-GB) and
**RDS Multi-AZ** (roughly double a single-AZ instance, since you're paying
for the standby too). Both are the right call to demonstrate HA design, but
**tear this down when you're done demoing** — see the teardown steps at the
bottom of `docs/SETUP.md`.

## 🔭 Next Steps (documented, not yet implemented)

- HTTPS on the ALB via ACM (currently HTTP-only for simplicity)
- Convert console steps to Terraform/CloudFormation for repeatable, version-controlled infra
- Add the CI/CD pipeline from Project 5 to auto-deploy app changes
- Add read replicas if read traffic grows beyond what the primary can handle

## 👤 About

Built by Ayomide Oladapo as a hands-on AWS portfolio project, applying
HA web architecture, IAM least-privilege, and Multi-AZ database design
learned through AWS Cloud Practitioner and the AWS re/Start program.
