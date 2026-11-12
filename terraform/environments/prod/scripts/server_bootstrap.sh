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

systemctl daemon-reload
systemctl enable --now minecraft_server


