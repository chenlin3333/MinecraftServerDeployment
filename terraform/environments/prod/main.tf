terraform {
  required_version = "1.17.2"

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


/*
  Compute and Storage Configuration
*/
resource "aws_instance" "minecraft_server" {
  ami               = data.aws_ami.aws_linux_ami.id
  instance_type     = "t4g.medium"
  availability_zone = var.availability_zone

  user_data = templatefile("${path.module}/scripts/server_bootstrap.sh", {
    java_version         = var.java_version
    minecraft_server_url = var.minecraft_server_url
    initial_ram_size     = var.initial_ram_size
    max_ram_size         = var.max_ram_size
    idle_timeout         = var.idle_timeout
    server_address            = aws_eip.minecraft_server_eip.public_ip
    region               = data.aws_region.current.name
    idle_monitor_script  = file("${path.module}/scripts/idle_monitor.py")
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
    Name   = "minecraft-server-storage"
    Backup = "true"
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

resource "aws_iam_role" "dlm_role" {
  name = "minecraft-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "dlm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dlm_policy" {
  role       = aws_iam_role.dlm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "minecraft_backup" {
  description        = "Daily Minecraft EBS backups"
  execution_role_arn = aws_iam_role.dlm_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Backup = "true"
    }

    schedule {
      name = "Daily Backups"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        BackupType = "Minecraft"
      }

      copy_tags = true
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.dlm_policy
  ]
}

/*
  Networking configurations
*/

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

  ingress {
    description = "Allow SSH access for debugging only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "minecraft_server_eip" {
  domain = "vpc"

  tags = {
    Name = "minecraft-server-eip"
  }
}

resource "aws_eip_association" "minecraft_eip_association" {
  instance_id   = aws_instance.minecraft_server.id
  allocation_id = aws_eip.minecraft_server_eip.id
}

/*
  Server State Infrastructure
*/


