import asyncio
import boto3
import os
import time

INSTANCE_ID = os.environ.get("INSTANCE_ID")
REGION = os.environ.get("REGION")
MINECRAFT_PORT = 25565
STARTUP_TIMEOUT = 200
RETRY_INTERVAL = 3

ec2 = boto3.client("ec2", region_name=REGION)

# Prevent multiple instances from starting the server simultaneously
startup_lock = asyncio.Lock()

def get_instance_info():
    response = ec2.describe_instances(
        InstanceIds=[INSTANCE_ID]
    )

    instance = response["Reservations"][0]["Instances"][0]

    return {
        "state": instance["State"]["Name"],
        "private_ip": instance.get("PrivateIpAddress")
    }

async def start_minecraft():
    async with startup_lock:
        deadline = time.monotonic() + STARTUP_TIMEOUT
        start_requested = False

        while time.monotonic() < deadline:
            info = await asyncio.to_thread(get_instance_info)
            state = info["state"]
            print(f"Minecraft EC2 state: {state}")

            if state == "running":
                print("Minecraft EC2 is running!")
                return info["private_ip"]
            elif state == "stopped":
                if not start_requested:
                    print("Starting Minecraft EC2...")
                    await asyncio.to_thread(
                        ec2.start_instances,
                        InstanceIds=[INSTANCE_ID]
                    )
                    start_requested = True
            elif state in ("shutting-down", "terminated"):
                raise RuntimeError(
                    f"Cannot start EC2. State: {state}"
                )
            await asyncio.sleep(RETRY_INTERVAL)

        raise TimeoutError("Minecraft EC2 startup timed out")

async def wait_for_minecraft(private_ip):
    print("Waiting for Minecraft server to become ready...")
    deadline = time.monotonic() + STARTUP_TIMEOUT

    while time.monotonic() < deadline:
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(
                    private_ip,
                    MINECRAFT_PORT
                ),
                timeout=2
            )
            writer.close()
            await writer.wait_closed()

            print("Minecraft server is accepting connections!")
            return
        except (OSError, asyncio.TimeoutError):
            await asyncio.sleep(RETRY_INTERVAL)
    raise TimeoutError("Minecraft server did not become ready")

async def forward_traffic(
    client_reader,
    client_writer,
    server_reader,
    server_writer
):
    async def pipe(reader, writer):
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                writer.write(data)
                await writer.drain()
        except (ConnectionError, OSError):
            pass

    tasks = [
        asyncio.create_task(
            pipe(client_reader, server_writer)
        ),
        asyncio.create_task(
            pipe(server_reader, client_writer)
        )
    ]

    try:
        done, pending = await asyncio.wait(
            tasks,
            return_when=asyncio.FIRST_COMPLETED
        )

        for task in pending:
            task.cancel()
        await asyncio.gather(*pending, return_exceptions=True)

    finally:
        server_writer.close()
        client_writer.close()

        await asyncio.gather(
            server_writer.wait_closed(),
            client_writer.wait_closed(),
            return_exceptions=True
        )

async def handle_connection(client_reader, client_writer):
    client_address = client_writer.get_extra_info("peername")
    print(f"Player connecting: {client_address}")
    server_writer = None

    try:
        # Start Minecraft if necessary
        private_ip = await start_minecraft()

        # Wait until Minecraft is listening
        await wait_for_minecraft(private_ip)

        # Connect player to Minecraft
        print(f"Forwarding player to {private_ip}")

        server_reader, server_writer = await asyncio.wait_for(
            asyncio.open_connection(
                private_ip,
                MINECRAFT_PORT
            ),
            timeout=10
        )

        # Forward traffic in both directions
        await forward_traffic(
            client_reader,
            client_writer,
            server_reader,
            server_writer
        )
        print(f"Player disconnected: {client_address}")
    except Exception as error:
        print(f"Connection failed: {error}")
    finally:
        client_writer.close()
        await asyncio.gather(
            client_writer.wait_closed(),
            return_exceptions=True
        )
        if server_writer is not None and not server_writer.is_closing():
            server_writer.close()

async def main():
    server = await asyncio.start_server(
        handle_connection,
        LISTEN_HOST,
        LISTEN_PORT
    )

    print(
        f"Minecraft proxy listening on "
        f"{LISTEN_HOST}:{LISTEN_PORT}"
    )
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Proxy shutting down")