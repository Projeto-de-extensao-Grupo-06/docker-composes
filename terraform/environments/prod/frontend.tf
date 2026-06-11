# frontend.tf - PROD (Frontend Domain: Institutional + Management)

module "ec2_frontend_1" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "frontend-1"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[0]
  frontend_ports       = [8081] # Institucional
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    export FRONTEND_TYPE="institutional"
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_frontend_2" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "frontend-2"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[0]
  frontend_ports       = [8080] # Management
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    export FRONTEND_TYPE="management"
    bash /tmp/setup-vm.sh
  EOT
}

resource "aws_ssm_association" "env_frontend_1" {
  depends_on = [aws_ssm_association.env_backend_1]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_frontend_1.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/frontend/institucional-website",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.frontend.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/frontend/institucional-website/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/frontend/institucional-website/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-frontend.sh"),
      "EOF",
      "export FRONTEND_TYPE='institutional'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_frontend_2" {
  depends_on = [aws_ssm_association.env_backend_1]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_frontend_2.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/frontend/management-system",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.frontend.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/frontend/management-system/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/frontend/management-system/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-frontend.sh"),
      "EOF",
      "export FRONTEND_TYPE='management'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
