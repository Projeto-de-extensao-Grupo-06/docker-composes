# database.tf - PROD (DB Domain: MySQL + Redis)

module "ec2_db" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "database"
  instance_type        = "t3.large"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[2]
  frontend_ports       = [3306, 6379]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

resource "aws_ssm_association" "env_db" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_db.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/db/mysql-init",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      templatefile("${path.module}/templates/env.db.tmpl", {
        db_username         = var.db_username
        db_password         = var.db_password
        redis_password      = var.redis_password
        github_username     = var.github_username
        github_access_token = var.github_token
      }),
      "ENVEOF",
      "cat > /tmp/solarway/services/db/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/db/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/services/db/mysql-init/init.sql << 'SQLEOF'",
      file("../../../services/db/mysql-init/init.sql"),
      "SQLEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-db.sh"),
      "EOF",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo bash /tmp/solarway/setup-app.sh",
      "sudo docker exec -i mysql-db mysql -u root -p'${var.db_password}' solarway < /tmp/solarway/services/db/mysql-init/init.sql"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
