# CIDR Plan

| Resource | CIDR | AZ | Tier | Notes |
|---|---|---|---|---|
| VPC | `10.1.0.0/16` | — | — | Standalone VPC, separate range from the VPC lab (`10.0.0.0/16`) |
| `public-subnet-a` | `10.1.0.0/24` | AZ #1 | Web | ALB node + NAT Gateway |
| `public-subnet-b` | `10.1.1.0/24` | AZ #2 | Web | ALB node |
| `app-subnet-a` | `10.1.10.0/24` | AZ #1 | App | EC2 Auto Scaling Group instances |
| `app-subnet-b` | `10.1.11.0/24` | AZ #2 | App | EC2 Auto Scaling Group instances |
| `db-subnet-a` | `10.1.20.0/24` | AZ #1 | Data | RDS primary |
| `db-subnet-b` | `10.1.21.0/24` | AZ #2 | Data | RDS standby (Multi-AZ automatic failover target) |

**Growth room:** `10.1.30.0/24` and beyond remain free for a future 4th
tier (e.g. a caching layer with ElastiCache) without re-planning the VPC.

**Why 3 separate tiers instead of reusing 2 subnets:** each tier has a
distinct trust boundary — web is internet-facing, app is internal-only
with outbound, data is fully isolated. Collapsing any two of these into
one subnet would collapse their security group boundary too.
