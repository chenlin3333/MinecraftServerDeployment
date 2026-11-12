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