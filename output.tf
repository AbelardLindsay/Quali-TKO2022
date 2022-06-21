output "instance_ips" {
  value = [aws_instance.webserver.public_ip, aws_instance.webserver.private_ip, aws_instance.mysqlserver.private_ip]
}