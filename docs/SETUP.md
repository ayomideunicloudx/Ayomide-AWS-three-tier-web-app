# Setup Guide — AWS Console Steps

Follow in order. Estimated time: 90–120 minutes (RDS creation alone takes
10–15 minutes). Use the values in `../configs/cidr-plan.md` and
`../configs/security-groups.md` as you go.

---

## 1. Create the VPC

1. **VPC → Your VPCs → Create VPC** → **VPC only**.
2. Name: `vpc-three-tier-app`. IPv4 CIDR: `10.1.0.0/16`. Create.

## 2. Create the Subnets

Create 6 subnets, all inside `vpc-three-tier-app`:

| Name | AZ | CIDR |
|---|---|---|
| `public-subnet-a` | AZ #1 | `10.1.0.0/24` |
| `public-subnet-b` | AZ #2 | `10.1.1.0/24` |
| `app-subnet-a` | AZ #1 | `10.1.10.0/24` |
| `app-subnet-b` | AZ #2 | `10.1.11.0/24` |
| `db-subnet-a` | AZ #1 | `10.1.20.0/24` |
| `db-subnet-b` | AZ #2 | `10.1.21.0/24` |

Enable **Auto-assign public IPv4 address** on `public-subnet-a` and
`public-subnet-b` only. Leave it off for all four private subnets.

## 3. Internet Gateway + NAT Gateway

1. **VPC → Internet Gateways → Create** → name `igw-three-tier-app` → attach to `vpc-three-tier-app`.
2. **VPC → NAT Gateways → Create** → subnet: `public-subnet-a` → allocate a new Elastic IP → Create. Wait for status **Available**.

## 4. Route Tables

**`rt-public`:** routes `0.0.0.0/0` → Internet Gateway. Associate with `public-subnet-a` and `public-subnet-b`.

**`rt-app`:** routes `0.0.0.0/0` → NAT Gateway. Associate with `app-subnet-a` and `app-subnet-b`.

**`rt-db`:** no internet route — just the automatic local route. Associate with `db-subnet-a` and `db-subnet-b`.

(Full detail in `../configs/route-tables.md`.)

## 5. Security Groups

Create three, all in `vpc-three-tier-app` (full rule tables in `../configs/security-groups.md`):

1. `sg-alb` — inbound HTTP (80) from `0.0.0.0/0`.
2. `sg-app` — inbound HTTP (80) from `sg-alb` **only**. No SSH rule.
3. `sg-db` — inbound MySQL/Aurora (3306) from `sg-app` **only**.

> Create `sg-alb` and `sg-app` first — you'll need their IDs as the
> "source" when creating the other groups' inbound rules.

## 6. Create the RDS Database

1. **RDS → Databases → Create database**.
2. Engine: **MySQL**. Templates: **Dev/Test** (or Production if you want Multi-AZ pre-selected).
3. DB instance identifier: `three-tier-app-db`.
4. **Credentials management**: choose **Managed in AWS Secrets Manager** — this is what lets `user-data.sh` fetch credentials without you ever typing a password into a script. Note the secret name it creates.
5. Instance size: `db.t3.micro` (Free Tier eligible) is enough for a demo.
6. **Multi-AZ deployment**: choose **Create a standby instance** (this is the HA feature this whole project demonstrates).
7. **Connectivity**: VPC: `vpc-three-tier-app`. Create a new **DB subnet group** using `db-subnet-a` and `db-subnet-b`. **Public access: No**. VPC security group: select existing → `sg-db` (remove the default one).
8. Initial database name: `threetierapp` (must match `DB_NAME` in `scripts/user-data.sh`).
9. Create database. **This takes 10–15 minutes** — continue with the next steps while it provisions.

## 7. Create the IAM Role for App Instances

1. **IAM → Roles → Create role** → Trusted entity: **AWS service** → Use case: **EC2**.
2. Attach the AWS-managed policy **AmazonSSMManagedInstanceCore** (enables Session Manager — no SSH needed).
3. Create a new custom policy using `../policies/ec2-instance-role-policy.json` (fill in your region, account ID, and the Secrets Manager secret name from step 6.4) → attach it too.
4. Name the role `three-tier-app-instance-role` → Create.

## 8. Create the Launch Template

1. **EC2 → Launch Templates → Create launch template**.
2. Name: `three-tier-app-lt`.
3. AMI: Amazon Linux 2023 (free tier eligible). Instance type: `t2.micro` or `t3.micro`.
4. **Key pair**: **not required** — leave as "Don't include in launch template" (Session Manager replaces SSH).
5. Network settings: Security group → select existing → `sg-app`.
6. **IAM instance profile**: select `three-tier-app-instance-role`.
7. **User data**: paste the contents of `../scripts/user-data.sh`, with `AWS_REGION` and `SECRET_NAME` filled in at the top. For the app deployment, replace the placeholder heredoc block with the full contents of `../app/index.php`.
8. Create launch template.

## 9. Create the Target Group and ALB

**Target group:**
1. **EC2 → Target Groups → Create target group** → target type: **Instances**.
2. Name: `three-tier-tg`. Protocol: HTTP, port 80. VPC: `vpc-three-tier-app`.
3. Health check path: `/index.php`. Create.

**ALB:**
1. **EC2 → Load Balancers → Create load balancer → Application Load Balancer**.
2. Name: `three-tier-alb`. Scheme: **internet-facing**.
3. VPC: `vpc-three-tier-app`. Mappings: select `public-subnet-a` and `public-subnet-b`.
4. Security group: `sg-alb`.
5. Listener: HTTP:80 → forward to `three-tier-tg`.
6. Create.

## 10. Create the Auto Scaling Group

1. **EC2 → Auto Scaling Groups → Create Auto Scaling group**.
2. Name: `three-tier-asg`. Launch template: `three-tier-app-lt`.
3. VPC: `vpc-three-tier-app`. Subnets: `app-subnet-a`, `app-subnet-b`.
4. Attach to the existing load balancer target group: `three-tier-tg`.
5. Health checks: enable **ELB health checks** (not just EC2 status checks).
6. Group size: desired 2, min 2, max 4.
7. Scaling policy: **Target tracking** → metric: **Average CPU utilization**, target value: `50`.
8. Create.

Wait a few minutes for instances to launch and pass health checks
(**EC2 → Target Groups → three-tier-tg → Targets** tab should show
"healthy").

## 11. Validate

1. Copy the ALB's DNS name from **EC2 → Load Balancers**.
2. Edit `../scripts/test-app.sh` with that DNS name.
3. Run:
   ```bash
   chmod +x scripts/test-app.sh
   ./scripts/test-app.sh
   ```
4. Or just visit `http://<alb-dns-name>` in a browser.

To manually inspect an app instance without SSH: **EC2 → Instances →
select instance → Connect → Session Manager tab → Connect**.

## 12. Teardown (avoid surprise charges)

RDS Multi-AZ and the NAT Gateway are the two ongoing costs here.

1. Delete the Auto Scaling Group (terminates its instances automatically).
2. Delete the ALB, then the target group.
3. Delete the RDS instance (uncheck "Create final snapshot" only if you're sure you don't need it).
4. Delete the NAT Gateway, then release its Elastic IP.
5. Detach and delete the Internet Gateway.
6. Delete all 3 route tables, all 6 subnets, the security groups, then the VPC.
7. Delete the IAM role and its custom policy.
