<?php
// index.php — Demo homepage for the three-tier app.
// Proves: (1) this instance is being served through the ALB, and
//         (2) it can reach the RDS database through the app-tier security group.

require __DIR__ . '/config.php'; // written by scripts/user-data.sh at boot

// Get this instance's ID from EC2 instance metadata (IMDSv2)
function get_instance_id() {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "http://169.254.169.254/latest/api/token");
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "PUT");
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["X-aws-ec2-metadata-token-ttl-seconds: 21600"]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 2);
    $token = curl_exec($ch);
    curl_close($ch);

    if (!$token) return "unavailable";

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "http://169.254.169.254/latest/meta-data/instance-id");
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["X-aws-ec2-metadata-token: $token"]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 2);
    $id = curl_exec($ch);
    curl_close($ch);

    return $id ?: "unavailable";
}

$instance_id = get_instance_id();
$db_status = "❌ Not connected";
$db_error = "";

try {
    $dsn = "mysql:host=" . DB_HOST . ";port=" . DB_PORT . ";dbname=" . DB_NAME;
    $pdo = new PDO($dsn, DB_USER, DB_PASS, [PDO::ATTR_TIMEOUT => 3]);
    $db_status = "✅ Connected";
} catch (PDOException $e) {
    $db_error = $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Three-Tier App Demo</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #0f172a; color: #e2e8f0; display: flex; justify-content: center; padding: 3rem 1rem; }
    .card { background: #1e293b; border-radius: 12px; padding: 2rem; max-width: 480px; width: 100%; box-shadow: 0 4px 14px rgba(0,0,0,0.3); }
    h1 { color: #38bdf8; margin-top: 0; }
    .row { display: flex; justify-content: space-between; padding: 0.6rem 0; border-bottom: 1px solid #334155; }
    .row:last-child { border-bottom: none; }
    .label { opacity: 0.7; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🏗️ Three-Tier App</h1>
    <div class="row"><span class="label">Served by (EC2 instance)</span><span><?= htmlspecialchars($instance_id) ?></span></div>
    <div class="row"><span class="label">Database connection</span><span><?= $db_status ?></span></div>
    <?php if ($db_error): ?>
      <p style="color:#f87171; font-size:0.85rem;">Note: DB error suppressed from public view in a real deployment; shown here only for lab debugging.</p>
    <?php endif; ?>
    <p style="font-size:0.85rem; opacity:0.6; margin-top:1.5rem;">
      This page was routed through the ALB, is running on an EC2 instance in a
      private app subnet with no public IP, and connects to a Multi-AZ RDS
      instance that also has no internet route.
    </p>
  </div>
</body>
</html>
