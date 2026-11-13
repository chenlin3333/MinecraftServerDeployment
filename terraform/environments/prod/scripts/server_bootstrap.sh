#!/bin/bash

export JAVA_VERSION="${java_version}"
export MINECRAFT_SERVER_URL="${minecraft_server_url}"
export INITIAL_RAM_SIZE="${initial_ram_size}"
export MAX_RAM_SIZE="${max_ram_size}"

sudo dnf install -y java-"$JAVA_VERSION"-amazon-corretto-headless

curl -o server.jar "$MINECRAFT_SERVER_URL"
sudo mkdir -p /opt/minecraft/server
sudo mv server.jar /opt/minecraft/server/
sudo chown -R ec2-user:ec2-user /opt/minecraft

cat <<EOF > /etc/systemd/system/minecraft_server.service
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/minecraft/server
ExecStart=/usr/bin/java -Xmx$${MAX_RAM_SIZE} -Xms$${INITIAL_RAM_SIZE} -jar server.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now minecraft_server
sudo systemctl start minecraft_server

# wait for the eula agreement file to be created
while [ ! -f /opt/minecraft/server/eula.txt ]; do
  sleep 1
done

sed -i 's/eula=false/eula=true/' /opt/minecraft/server/eula.txt
sudo systemctl restart minecraft_server

