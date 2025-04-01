#!/bin/bash

sudo bash -c "cat > /usr/local/bin/memory_monitor.sh" << 'SCRIPT'
#!/bin/bash
MEM_USAGE=$(free | awk '/Mem:/ {print $3/$2 * 100}')
if (( $(echo "$MEM_USAGE > 13" | bc -l) )); then
    echo "Memory usage exceeded 13%: $MEM_USAGE%"
    sudo systemctl restart 0gd
    echo "0gd service has been restarted."
    echo "$(date): Memory usage: $MEM_USAGE%, 0gd restarted" >> /var/log/memory_monitor.log
else
    echo "Memory usage: $MEM_USAGE% (below 13%)"
fi
SCRIPT

sudo chmod +x /usr/local/bin/memory_monitor.sh

sudo bash -c "cat > /etc/systemd/system/memory-monitor.service" << 'SERVICE'
[Unit]
Description=Memory usage monitoring and 0gd restart

[Service]
ExecStart=/usr/local/bin/memory_monitor.sh
Type=oneshot
SERVICE

sudo bash -c "cat > /etc/systemd/system/memory-monitor.timer" << 'TIMER'
[Unit]
Description=Memory usage check timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=30s
Unit=memory-monitor.service

[Install]
WantedBy=timers.target
TIMER

echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart 0gd" | sudo tee -a /etc/sudoers

sudo systemctl daemon-reload
sudo systemctl enable memory-monitor.timer
sudo systemctl start memory-monitor.timer

echo "Installation completed. Check status with: systemctl status memory-monitor.timer"
