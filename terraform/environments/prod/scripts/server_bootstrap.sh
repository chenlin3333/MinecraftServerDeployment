#!/bin/bash

export JAVA_VERSION="${java_version}"
export MINECRAFT_SERVER_URL="${minecraft_server_url}"
export INITIAL_RAM_SIZE="${initial_ram_size}"
export MAX_RAM_SIZE="${max_ram_size}"
export IDLE_TIMEOUT="${idle_timeout}"
export SERVER_ADDRESS="${server_address}"
export REGION="${region}"

mount_EBS_volume() {
    sudo mkdir -p /mnt/minecraft/server
    sudo groupadd minecraft-user
    sudo adduser --system -g minecraft-user --home /mnt/minecraft/server minecraft-user

    # Wait for the EBS device to be available
    while [ ! -b /dev/sdf ]; do
        sleep 1
    done
    sudo mkfs -t ext4 /dev/sdf
    sudo mount /dev/sdf /mnt/minecraft/server
}

install_dependencies() {
    sudo dnf install -y java-"$JAVA_VERSION"-amazon-corretto-headless
    sudo dnf install python3-pip -y
    pip3 install mcstatus
    cat <<EOF > /opt/idle_monitor.py
${idle_monitor_script}
EOF
    chmod +x /opt/idle_monitor.py
}

install_dependencies
mount_EBS_volume

metadata_token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $metadata_token" -s http://169.254.169.254/latest/meta-data/instance-id)
curl -o server.jar "$MINECRAFT_SERVER_URL"
sudo mv server.jar /mnt/minecraft/server/
sudo chown -R minecraft-user:minecraft-user /mnt/minecraft/server

cat <<EOF > /etc/systemd/system/minecraft_server.service
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft-user
WorkingDirectory=/mnt/minecraft/server
ExecStart=/usr/bin/java -Xmx$${MAX_RAM_SIZE} -Xms$${INITIAL_RAM_SIZE} -jar server.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/systemd/system/minecraft_server_monitor.service
[Unit]
Description=Monitor Minecraft Server player count
After=minecraft_server.service

[Service]
User=minecraft-user
ExecStartPre=/bin/sleep 15
ExecStart=/usr/bin/python3 /opt/idle_monitor.py
Restart=on-failure

Environment="INSTANCE_ID=$INSTANCE_ID"
Environment="IDLE_TIMEOUT=$IDLE_TIMEOUT"
Environment="SERVER_ADDRESS=$SERVER_ADDRESS"
Environment="REGION=$REGION"
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=minecraft_server.service
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now minecraft_server
sudo systemctl enable --now minecraft_server_monitor
sudo systemctl start minecraft_server

# wait for the eula agreement file to be created
while [ ! -f /mnt/minecraft/server/eula.txt ]; do
  sleep 1
done

sed -i 's/eula=false/eula=true/' /mnt/minecraft/server/eula.txt
sed -i 's/white-list=true/white-list=false/' /mnt/minecraft/server/server.properties
sudo systemctl restart minecraft_server

