terraform {
  required_version = "1.17.1"

  cloud {
    organization = "MinecraftServerDeployment"

    workspaces {
      name = "MinecraftServerDeployment-Prod"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "minecraft_server" {
  ami           = data.aws_ami.aws_linux_ami.id
  instance_type = "t4g.medium"

  user_data = templatefile("${path.module}/scripts/server_bootstrap.sh", {
    java_version         = var.java_version
    minecraft_server_url = var.minecraft_server_url
    initial_ram_size     = var.initial_ram_size
    max_ram_size         = var.max_ram_size
  })

  user_data_replace_on_change = true

  vpc_security_group_ids = [
    aws_security_group.minecraft_server_sg.id
  ]

  tags = {
    Name = "Minecraft-Server-EC2"
  }
}

resource "aws_ebs_volume" "minecraft_server_storage" {
  availability_zone = aws_instance.minecraft_server.availability_zone
  size             = 20
  type             = "gp3"

  tags = {
    Name = "minecraft-server-torage"
  }
}

resource "aws_volume_attachment" "minecraft_server_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.minecraft_server_storage.id
  instance_id = aws_instance.minecraft_server.id
}

resource "aws_vpc" "minecraft_server_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "minecraft-server-vpc"
  }
}

resource "aws_security_group" "minecraft_server_sg" {
  name = "minecraft-server-security-group"
  vpc_id = aws_vpc.minecraft_server_vpc.id

  ingress { 
    description = "Allow players to connect to the server listening on port 25565"
    from_port = 25565
    to_port = 25565
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH access for debugging only"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["8.9.95.96/32"]
  }
}