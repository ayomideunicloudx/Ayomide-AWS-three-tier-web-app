#!/usr/bin/env bash
#
# test-app.sh — Validates the three-tier deployment from outside AWS,
# the way a real user would hit it.
#
# Run from your LOCAL machine. Requires curl.

set -euo pipefail

# ── EDIT THIS ────────────────────────────────────────────────────────────
ALB_DNS_NAME="YOUR_ALB_DNS_NAME"   # e.g. three-tier-alb-123456789.us-east-1.elb.amazonaws.com
# ───────────────────────────────────────────────────────────────────────

echo "▶ Test 1: Is the ALB responding on HTTP?"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS_NAME" --max-time 10 || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✅ ALB responded 200 OK."
else
  echo "  ❌ ALB returned HTTP $HTTP_CODE. Check target group health in the EC2 console."
  exit 1
fi

echo ""
echo "▶ Test 2: Does the page confirm a live DB connection?"
PAGE_BODY=$(curl -s "http://$ALB_DNS_NAME" --max-time 10)

if echo "$PAGE_BODY" | grep -q "✅ Connected"; then
  echo "  ✅ App reports a successful database connection."
elif echo "$PAGE_BODY" | grep -q "❌ Not connected"; then
  echo "  ⚠️  App is up but reports it could NOT connect to the database."
  echo "      Check: sg-db allows 3306 from sg-app, the Secrets Manager"
  echo "      secret name in user-data.sh is correct, and the instance"
  echo "      role has secretsmanager:GetSecretValue on that secret."
else
  echo "  ⚠️  Could not determine DB status from the page — is app/index.php fully deployed?"
fi

echo ""
echo "▶ Test 3 (informational): Confirm no direct access to app or DB tiers"
echo "  These should NOT be reachable from your machine at all (no public IP):"
echo "    - App tier EC2 instances (check their private IPs in the EC2 console)"
echo "    - RDS endpoint on port 3306 (check the RDS console — 'Publicly accessible' should read 'No')"
echo ""
echo "Done. Re-run after making changes — the ALB may take ~30s to reflect new healthy targets."
