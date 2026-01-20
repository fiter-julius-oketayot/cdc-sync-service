#!/bin/bash

# Simple Dashboard Creator for GoldenGate - Bash Version

echo "============================================"
echo "Creating GoldenGate Management Dashboard"
echo "============================================"

# Create simple HTML dashboard
cat > "../goldengate-dashboard.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GoldenGate CDC Management</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #d62728; border-bottom: 3px solid #d62728; padding-bottom: 10px; }
        .section { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 5px; }
        .command { background: #e9ecef; padding: 10px; border-radius: 3px; font-family: monospace; margin: 10px 0; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; background: #fff3cd; border: 1px solid #ffeaa7; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Oracle GoldenGate CDC Management Dashboard</h1>

        <div class="status">
            <strong>Alternative Web Interface</strong><br>
            This dashboard provides manual configuration steps for Oracle GoldenGate CDC setup.
        </div>

        <div class="section">
            <h2>Configuration Steps</h2>

            <h3>1. Access Oracle GoldenGate Container</h3>
            <div class="command">docker exec -it goldengate-oracle bash</div>

            <h3>2. Configure Oracle Extract Process</h3>
            <div class="command">
cd /u01/ogg<br>
./ggsci<br>
DBLOGIN USERID oggadmin, PASSWORD Welcome1<br>
ADD EXTRACT ext_oracle, TRANLOG, BEGIN NOW<br>
START EXTRACT ext_oracle<br>
EXIT
            </div>

            <h3>3. Access PostgreSQL GoldenGate Container</h3>
            <div class="command">docker exec -it goldengate-postgres bash</div>

            <h3>4. Configure PostgreSQL Replicat Process</h3>
            <div class="command">
cd /u01/ogg<br>
./ggsci<br>
ADD REPLICAT rep_postgres, EXTTRAIL ./dirdat/lt<br>
START REPLICAT rep_postgres<br>
EXIT
            </div>
        </div>

        <div class="section">
            <h2>Web UI Access</h2>
            <p>Oracle GoldenGate: <a href="http://localhost:9100">http://localhost:9100</a></p>
            <p>PostgreSQL GoldenGate: <a href="http://localhost:9200">http://localhost:9200</a></p>
            <p>Username: oggadmin | Password: Welcome1</p>
        </div>
    </div>
</body>
</html>
EOF

echo "✅ Dashboard created successfully!"
echo "📖 Dashboard location: ../goldengate-dashboard.html"
echo "🌐 Open the HTML file in your web browser"
echo ""
