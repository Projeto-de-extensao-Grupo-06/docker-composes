# network.tf - PROD

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "vpc_prod" {
  source = "../../modules/vpc"

  environment = "prod"
  vpc_cidr    = "10.0.0.0/24"

  # Subnet Pública
  public_subnets = ["10.0.0.0/28"]

  # Subnets Privadas
  private_subnets = [
    "10.0.0.16/28", # Frontend
    "10.0.0.32/28", # Backend
    "10.0.0.48/28", # DB
    "10.0.0.64/28"  # Innovation/Workers
  ]

  azs = ["us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a", "us-east-1a"]

  enable_nat_gateway = var.use_nat_gateway
}

module "ec2_nginx" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "nginx-proxy"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.public_subnet_ids[0]
  frontend_ports       = [80, 443, 3000, 3001, 5678, 8081, 15672]
  iam_instance_profile = "LabInstanceProfile"
  source_dest_check    = false

  user_data = <<-EOT
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    mkdir -p /tmp/solarway/services/proxy
    mkdir -p /tmp/solarway/scripts/setup/prod

    # Docker config
    base64 -d << 'EOF' > /tmp/solarway/services/proxy/docker-compose.yml
    ${base64encode(file("../../../services/proxy/docker-compose.yml"))}
    EOF

    cat << 'EOF' > /tmp/solarway/services/proxy/nginx.conf.template
    ${file("../../../services/proxy/nginx.conf.template")}
    EOF

    # Runtime Env
    cat << EOF > /tmp/solarway/.env
    BACKEND_PRIVATE_IP=${module.ec2_backend_1.private_ip}
    MANAGEMENT_PRIVATE_IP=${module.ec2_frontend_2.private_ip}
    INSTITUCIONAL_PRIVATE_IP=${module.ec2_frontend_1.private_ip}
    N8N_PRIVATE_IP=${module.ec2_chatbot.private_ip}
    WAHA_PRIVATE_IP=${module.ec2_chatbot.private_ip}
    MICROSERVICE_PRIVATE_IP=${module.ec2_backend_2.private_ip}
    GRAFANA_PRIVATE_IP=${module.ec2_grafana.private_ip}
    DOMAIN=${var.domain}
    EMAIL=${var.email}
    GITHUB_USERNAME=${var.github_username}
    GITHUB_ACCESS_TOKEN=${var.github_token}
    EOF

    # Scripts
    cat << 'EOF' > /tmp/solarway/scripts/setup/setup-vm.sh
    ${file("../../../scripts/setup-vm.sh")}
    EOF

    cat << 'EOF' > /tmp/solarway/scripts/setup/prod/setup-proxy.sh
    ${file("./scripts/setup-proxy.sh")}
    EOF

    find /tmp/solarway -type f -name "*.sh" -exec sed -i 's/\r$//' {} +
    chmod +x /tmp/solarway/scripts/setup/setup-vm.sh /tmp/solarway/scripts/setup/prod/setup-proxy.sh
    
    sudo bash /tmp/solarway/scripts/setup/prod/setup-proxy.sh
  EOT
}

resource "aws_route" "private_nat_access" {
  count                  = var.use_nat_gateway ? 0 : 1
  route_table_id         = module.vpc_prod.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.ec2_nginx.primary_network_interface_id
}

resource "aws_security_group_rule" "proxy_nat_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = ["10.0.0.0/24"]
  security_group_id        = module.ec2_nginx.security_group_id
  description              = "Allow traffic from private subnets for NAT routing"
}

# SSM Association for Proxy Environment
resource "aws_ssm_association" "env_proxy" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_nginx.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/proxy",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      "BACKEND_PRIVATE_IP=${module.ec2_backend_1.private_ip}",
      "MANAGEMENT_PRIVATE_IP=${module.ec2_frontend_2.private_ip}",
      "INSTITUCIONAL_PRIVATE_IP=${module.ec2_frontend_1.private_ip}",
      "N8N_PRIVATE_IP=${module.ec2_chatbot.private_ip}",
      "WAHA_PRIVATE_IP=${module.ec2_chatbot.private_ip}",
      "MICROSERVICE_PRIVATE_IP=${module.ec2_backend_2.private_ip}",
      "GRAFANA_PRIVATE_IP=${module.ec2_grafana.private_ip}",
      "DOMAIN=${var.domain}",
      "EMAIL=${var.email}",
      "GITHUB_USERNAME=${var.github_username}",
      "GITHUB_ACCESS_TOKEN=${var.github_token}",
      "ENVEOF",
      "cat > /tmp/solarway/services/proxy/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/proxy/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/services/proxy/nginx.conf.template << 'CONFEOF'",
      file("../../../services/proxy/nginx.conf.template"),
      "CONFEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("./scripts/setup-proxy.sh"),
      "EOF",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
