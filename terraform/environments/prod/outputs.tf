# outputs.tf - PROD

output "nginx_public_ip" {
  description = "IP Público do Nginx Proxy (único ponto de entrada externo)"
  value       = module.ec2_nginx.public_ip
}

output "nginx_ssm_connect" {
  description = "SSM — Nginx Proxy"
  value       = "aws ssm start-session --target ${module.ec2_nginx.instance_id}"
}

output "nginx_logs" {
  description = "Logs — Nginx Proxy"
  value       = "aws ssm start-session --target ${module.ec2_nginx.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "backend_1_private_ip" {
  description = "IP Privado — Backend Monolito"
  value       = module.ec2_backend_1.private_ip
}

output "backend_1_ssm_connect" {
  description = "SSM — Backend Monolito"
  value       = "aws ssm start-session --target ${module.ec2_backend_1.instance_id}"
}

output "backend_1_logs" {
  description = "Logs — Backend Monolito"
  value       = "aws ssm start-session --target ${module.ec2_backend_1.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "backend_2_private_ip" {
  description = "IP Privado — Backend Microserviço"
  value       = module.ec2_backend_2.private_ip
}

output "backend_2_ssm_connect" {
  description = "SSM — Backend Microserviço"
  value       = "aws ssm start-session --target ${module.ec2_backend_2.instance_id}"
}

output "backend_2_logs" {
  description = "Logs — Backend Microserviço"
  value       = "aws ssm start-session --target ${module.ec2_backend_2.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "frontend_1_private_ip" {
  description = "IP Privado — Frontend Institucional"
  value       = module.ec2_frontend_1.private_ip
}

output "frontend_1_ssm_connect" {
  description = "SSM — Frontend Institucional"
  value       = "aws ssm start-session --target ${module.ec2_frontend_1.instance_id}"
}

output "frontend_1_logs" {
  description = "Logs — Frontend Institucional"
  value       = "aws ssm start-session --target ${module.ec2_frontend_1.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "frontend_2_private_ip" {
  description = "IP Privado — Frontend Management"
  value       = module.ec2_frontend_2.private_ip
}

output "frontend_2_ssm_connect" {
  description = "SSM — Frontend Management"
  value       = "aws ssm start-session --target ${module.ec2_frontend_2.instance_id}"
}

output "frontend_2_logs" {
  description = "Logs — Frontend Management"
  value       = "aws ssm start-session --target ${module.ec2_frontend_2.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "chatbot_private_ip" {
  description = "IP Privado — Chatbot (n8n + WAHA)"
  value       = module.ec2_chatbot.private_ip
}

output "chatbot_ssm_connect" {
  description = "SSM — Chatbot"
  value       = "aws ssm start-session --target ${module.ec2_chatbot.instance_id}"
}

output "chatbot_logs" {
  description = "Logs — Chatbot"
  value       = "aws ssm start-session --target ${module.ec2_chatbot.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "webscraping_private_ip" {
  description = "IP Privado — Web Scraping"
  value       = module.ec2_webscraping.private_ip
}

output "webscraping_ssm_connect" {
  description = "SSM — Web Scraping"
  value       = "aws ssm start-session --target ${module.ec2_webscraping.instance_id}"
}

output "webscraping_logs" {
  description = "Logs — Web Scraping"
  value       = "aws ssm start-session --target ${module.ec2_webscraping.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}

output "db_private_ip" {
  description = "IP Privado — Banco de Dados (MySQL + Redis)"
  value       = module.ec2_db.private_ip
}

output "db_ssm_connect" {
  description = "SSM — Banco de Dados"
  value       = "aws ssm start-session --target ${module.ec2_db.instance_id}"
}

output "db_logs" {
  description = "Logs — Banco de Dados"
  value       = "aws ssm start-session --target ${module.ec2_db.instance_id} --document-name AWS-StartInteractiveCommand --parameters command='tail -f /var/log/solarway-setup.log'"
}
