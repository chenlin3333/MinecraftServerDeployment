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

resource "aws_instance" "minecraft_server" {
  ami               = data.aws_ami.aws_linux_ami.id
  instance_type     = "t4g.medium"
  availability_zone = var.availability_zone

  user_data = templatefile("${path.module}/scripts/server_bootstrap.sh", {
    java_version         = var.java_version
    minecraft_server_url = var.minecraft_server_url
    initial_ram_size     = var.initial_ram_size
    max_ram_size         = var.max_ram_size
  })

  user_data_replace_on_change = true

  subnet_id = aws_subnet.public_subnet.id

  vpc_security_group_ids = [
    aws_security_group.minecraft_server_sg.id
  ]

  tags = {
    Name = "Minecraft-Server-EC2"
  }
}

resource "aws_ebs_volume" "minecraft_server_storage" {
  availability_zone = aws_instance.minecraft_server.availability_zone
  size              = var.storage_size
  type              = "gp3"

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
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "minecraft-server-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.minecraft_server_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.minecraft_server_vpc.id

  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.minecraft_server_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "minecraft_server_sg" {
  name   = "minecraft-server-security-group"
  vpc_id = aws_vpc.minecraft_server_vpc.id

  ingress {
    description = "Allow players to connect to the server listening on port 25565"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}