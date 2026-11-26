output "minecraft_server_public_ip" {
  description = "Elastic IP of minecraft server"
  value       = aws_eip.minecraft_server_eip.public_ip
}