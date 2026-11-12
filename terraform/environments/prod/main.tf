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

  tags = {
    Name = "Minecraft-Server-EC2"
  }
}