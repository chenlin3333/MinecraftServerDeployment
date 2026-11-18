output "minecraft_server_public_ip" {
    value = aws_instance.minecraft_server.public_ip
}

output "minecraft_server_public_dns" {
    value = aws_instance.minecraft_server.public_dns
}