import time
import subprocess
from mcstatus import JavaServer
import os

SERVER_ADDRESS = os.getenv("SERVER_ADDRESS")
IDLE_TIMEOUT = int(os.getenv("IDLE_TIMEOUT")) * 60
CHECK_INTERVAL = 60 #seconds
INSTANCE_ID = os.getenv("INSTANCE_ID")
REGION = os.getenv("REGION")
empty_since = None

server = JavaServer(SERVER_ADDRESS)

while True:
    try:
        status = server.status()
        players_online = status.players.online

        if players_online > 0:
            print(f"{players_online} players are online.")
            empty_since = None
        else:
            print("No players are online.")
            if empty_since is None:
                empty_since = time.time()
            idle_time = time.time() - empty_since

            if idle_time >= IDLE_TIMEOUT:
                print(f"IDLE for {IDLE_TIMEOUT} seconds. Shutting down the server.")
                
                subprocess.run(["systemctl", "stop", "minecraft"])
                subprocess.run(["aws", "ec2", "stop-instances", "--region", REGION, "--instance-ids", INSTANCE_ID])

                break
    except Exception as e:
        print(f"An error occurred: {e}")
    time.sleep(CHECK_INTERVAL)