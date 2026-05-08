# variables.tf - PROD

variable "use_nat_gateway" {
  description = "Se true, usa NAT Gateway (pago). Se false, usa Nginx como NAT Instance (grátis)."
  type        = bool
  default     = false
}

variable "db_username" {
  description = "Usuário do banco de dados MySQL"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Senha do banco de dados MySQL"
  type        = string
  sensitive   = true
}

variable "redis_user" {
  description = "Usuário do Redis"
  type        = string
  default     = "default"
}

variable "redis_password" {
  description = "Senha do Redis"
  type        = string
  sensitive   = true
}

variable "bot_secret" {
  description = "Secret do Bot WhatsApp"
  type        = string
  sensitive   = true
}

variable "email" {
  description = "E-mail de configuração para o Backend"
  type        = string
}

variable "email_password" {
  description = "Senha do e-mail (App Password)"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Nome do bucket S3 principal"
  type        = string
  default     = "solarway-datalake-trusted"
}

variable "github_username" {
  description = "Username do GitHub para pull de imagens privadas (ghcr.io)"
  type        = string
}

variable "github_token" {
  description = "PAT do GitHub para pull de imagens privadas (ghcr.io)"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domínio público para configuração do SSL (ex: solarway.com.br)"
  type        = string
  default     = "solarway.test"
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_session_token" {
  type      = string
  sensitive = true
}

variable "rabbitmq_default_user" {
  description = "Usuário do RabbitMQ"
  type        = string
  default     = "admin"
}

variable "rabbitmq_default_pass" {
  description = "Senha do RabbitMQ"
  type        = string
  default     = "0624"
}

variable "grafana_user" {
  description = "Usuário do Grafana"
  type        = string
  default     = "admin"
}

variable "grafana_password" {
  description = "Senha do Grafana"
  type        = string
  default     = "admin"
}
