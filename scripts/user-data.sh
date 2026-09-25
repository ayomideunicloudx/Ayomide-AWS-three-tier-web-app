#!/bin/bash
#
# user-data.sh — Paste this into the Launch Template's "User data" field
# (as plain text, not base64 — the console handles encoding for you).
#
# Runs once when each ASG instance boots. Installs the web stack, pulls
# DB credentials from Secrets Manager (never hardcoded), and deploys the
# demo app.
#
# EDIT THE VALUES BELOW before pasting into the Launch Template.

set -euo pipefail

# ── EDIT THESE ───────────────────────────────────────────────────────────
AWS_REGION="us-east-1"
SECRET_NAME="YOUR_RDS_SECRET_NAME"     # the Secrets Manager secret RDS created for you
# ─────────────────────────────────────────────────────────────────────────

# 1. Install the web stack (Amazon Linux 2023)
dnf update -y
dnf install -y httpd php php-mysqlnd jq

systemctl enable httpd
systemctl start httpd

# 2. Fetch DB credentials from Secrets Manager (requires the instance
#    role to have secretsmanager:GetSecretValue on this specific secret —
#    see policies/ec2-instance-role-policy.json)
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text)

DB_HOST=$(echo "$SECRET_JSON" | jq -r '.host')
DB_PORT=$(echo "$SECRET_JSON" | jq -r '.port')
DB_USER=$(echo "$SECRET_JSON" | jq -r '.username')
DB_PASS=$(echo "$SECRET_JSON" | jq -r '.password')
DB_NAME="threetierapp"   # set this to whatever DB name you created in RDS

# 3. Write config.php with the real values (never committed to git —
#    this file only exists on the running instance)
cat > /var/www/html/config.php <<PHP
<?php
define('DB_HOST', '${DB_HOST}');
define('DB_PORT', '${DB_PORT}');
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASS', '${DB_PASS}');
PHP

# 4. Deploy the demo homepage
#    (In a real pipeline this would come from CodeDeploy/S3 — for this
#    lab, copy the contents of app/index.php from the repo into this
#    heredoc, or scp/SSM-copy it onto the instance after boot.)
#    Placeholder below just confirms the boot script ran; replace with
#    the real app/index.php contents for the full working demo.
if [ ! -f /var/www/html/index.php ]; then
cat > /var/www/html/index.php <<'PHP'
<?php
// Replace this placeholder with the full contents of app/index.php
// from this repo for the complete demo experience.
echo "<h1>Bootstrap complete.</h1><p>Deploy app/index.php from the repo to finish setup.</p>";
PHP
fi

systemctl restart httpd

echo "✅ user-data.sh complete."
