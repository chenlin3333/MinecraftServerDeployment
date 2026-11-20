output "minecraft_server_public_ip" {
  description = "Elastic IP of minecraft server"
  value       = aws_eip.minecraft_server_eip.public_ip
}

output "minecraft_server_hostname" {
  value = aws_route53_record.minecraft_a_record.fqdn
}