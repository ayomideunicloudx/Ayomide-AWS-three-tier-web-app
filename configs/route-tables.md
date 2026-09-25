# Route Tables

## `rt-public`

| Destination | Target |
|---|---|
| `10.1.0.0/16` | local (default, automatic) |
| `0.0.0.0/0` | Internet Gateway |

**Associated subnets:** `public-subnet-a`, `public-subnet-b`

## `rt-app`

| Destination | Target |
|---|---|
| `10.1.0.0/16` | local (default, automatic) |
| `0.0.0.0/0` | NAT Gateway (in `public-subnet-a`) |

**Associated subnets:** `app-subnet-a`, `app-subnet-b`

## `rt-db`

| Destination | Target |
|---|---|
| `10.1.0.0/16` | local (default, automatic) |

**Associated subnets:** `db-subnet-a`, `db-subnet-b`

**No `0.0.0.0/0` route exists on this table — intentionally.** The
database subnets have zero path to the internet, in either direction.
This is the strictest isolation in the architecture: even if `sg-db`
were misconfigured, there's still no route out.

---

**Note on the single NAT Gateway:** `app-subnet-b` (AZ #2) routes its
outbound traffic through the NAT Gateway sitting in `public-subnet-a`
(AZ #1), crossing an AZ boundary — the same cost-vs-HA trade-off
documented in the VPC networking lab. A production setup would place a
second NAT Gateway in `public-subnet-b` for same-AZ routing.
