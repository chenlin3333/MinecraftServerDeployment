#!/bin/bash

export JAVA_VERSION="${java_version}"
export MINECRAFT_SERVER_URL="${minecraft_server_url}"
export INITIAL_RAM_SIZE="${initial_ram_size}"
export MAX_RAM_SIZE="${max_ram_size}"

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

mount_EBS_volume
sudo dnf install -y java-"$JAVA_VERSION"-amazon-corretto-headless

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

sudo systemctl daemon-reload
sudo systemctl enable --now minecraft_server
sudo systemctl start minecraft_server

# wait for the eula agreement file to be created
while [ ! -f /mnt/minecraft/server/eula.txt ]; do
  sleep 1
done

sed -i 's/eula=false/eula=true/' /mnt/minecraft/server/eula.txt
sudo systemctl restart minecraft_server

