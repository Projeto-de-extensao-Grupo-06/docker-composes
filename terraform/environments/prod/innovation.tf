# innovation.tf - PROD (Innovation Domain: Chatbot + Webscraping)

module "ec2_chatbot" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "chatbot"
  instance_type        = "t3.small"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[3]
  frontend_ports       = [3000, 5678]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export BOT_TYPE="chatbot"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

module "ec2_webscraping" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "webscraping"
  instance_type        = "t3.micro"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[3]
  frontend_ports       = [5000]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export BOT_TYPE="webscraping"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

resource "aws_ssm_association" "env_bot" {
  depends_on = [aws_ssm_association.env_backend_1]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_chatbot.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/bot",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.bot.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        db_private_ip       = module.ec2_db.private_ip
        nginx_public_ip     = module.ec2_nginx.public_ip
        bot_secret          = var.bot_secret
        db_username         = var.db_username
        db_password         = var.db_password
        redis_user          = var.redis_user
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/bot/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/bot/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-bot.sh"),
      "EOF",
      "export BOT_TYPE='chatbot'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}

resource "aws_ssm_association" "env_webscraping" {
  depends_on = [aws_ssm_association.env_db]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_webscraping.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/web-scrapping",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.bot.tmpl", {
        backend_1_ip        = module.ec2_backend_1.private_ip
        db_private_ip       = module.ec2_db.private_ip
        nginx_public_ip     = module.ec2_nginx.public_ip
        bot_secret          = var.bot_secret
        db_username         = var.db_username
        db_password         = var.db_password
        redis_user          = var.redis_user
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/web-scrapping/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/web-scrapping/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-bot.sh"),
      "EOF",
      "export BOT_TYPE='webscraping'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
