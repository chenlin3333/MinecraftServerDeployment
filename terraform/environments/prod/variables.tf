variable "java_version" {
  description = "The Java verion to use for the minecraft server"
  type        = string
  default     = "25"
}

variable "minecraft_server_url" {
  description = "The url to download minecraft server from"
  type        = string
  default     = "https://piston-data.mojang.com/v1/objects/33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c/server.jar"
}

variable "initial_ram_size" {
  description = "The amount of ram to reserve when the server starts up"
  type        = string
  default     = "3G"
}

variable "max_ram_size" {
  description = "The max amount of ram the server can use"
  type        = string
  default     = "3G"
}

variable "vpc_cidr" {
  description = "The range of IP addresses for my VPC"
  type        = string
  default     = "10.0.0.0/24"
}

variable "availability_zone" {
  description = "The AZ to host the minecraft server"
  type        = string
  default     = "us-east-1a"
}

variable "public_subnet_cidr" {
  description = "The range of IP addresses for my public subnet in the VPC"
  type        = string
  default     = "10.0.0.0/24"
}

variable "storage_size" {
  description = "The size in GB of the EBS volume for the minecraft server"
  type        = number
  default     = 20
}