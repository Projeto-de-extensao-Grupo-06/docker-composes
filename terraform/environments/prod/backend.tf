# backend.tf - PROD (Backend Domain: Monolith + Microservice)

module "ec2_backend_1" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "backend-1"
  instance_type        = "t3.medium"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[1]
  frontend_ports       = [8000] # Monolito
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    export BACKEND_TYPE="monolith"
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_backend_2" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "backend-2"
  instance_type        = "t3.medium"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[1]
  frontend_ports       = [8082, 5672, 15672] # Microserviço e RabbitMQ
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    export BACKEND_TYPE="microservice"
    bash /tmp/setup-vm.sh
  EOT
}

resource "aws_ssm_association" "env_backend_1" {
  depends_on = [aws_ssm_association.env_db]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_backend_1.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/backend/monolith",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.backend.tmpl", {
        db_private_ip       = module.ec2_db.private_ip
        db_password         = var.db_password
        bucket_name         = var.bucket_name
        email               = var.email
        email_password      = var.email_password
        bot_secret          = var.bot_secret
        github_username     = var.github_username
        github_access_token = var.github_token
        aws_access_key      = var.aws_access_key
        aws_secret_key      = var.aws_secret_key
        aws_session_token   = var.aws_session_token
        rabbitmq_default_user = var.rabbitmq_default_user
        rabbitmq_default_pass = var.rabbitmq_default_pass
        microservice_private_ip = module.ec2_backend_2.private_ip
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/backend/monolith/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/backend/monolith/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-backend.sh"),
      "EOF",
      "export BACKEND_TYPE='monolith'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_backend_2" {
  depends_on = [aws_ssm_association.env_db]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_backend_2.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/backend/microservice",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.backend.tmpl", {
        db_private_ip       = module.ec2_db.private_ip
        db_password         = var.db_password
        bucket_name         = var.bucket_name
        email               = var.email
        email_password      = var.email_password
        bot_secret          = var.bot_secret
        github_username     = var.github_username
        github_access_token = var.github_token
        aws_access_key      = var.aws_access_key
        aws_secret_key      = var.aws_secret_key
        aws_session_token   = var.aws_session_token
        rabbitmq_default_user = var.rabbitmq_default_user
        rabbitmq_default_pass = var.rabbitmq_default_pass
        microservice_private_ip = module.ec2_backend_2.private_ip
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/backend/microservice/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/backend/microservice/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-backend.sh"),
      "EOF",
      "export BACKEND_TYPE='microservice'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
