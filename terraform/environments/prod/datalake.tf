# datalake.tf - PROD (Data Lake Domain: S3 + Lambdas + Grafana)

# -- S3 Buckets (Data Lake Layers) ---------------------------------------------
module "s3_raw" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-raw"
}

module "s3_trusted" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-trusted"
}

module "s3_refined" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-refined"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc_prod.vpc_id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    module.vpc_prod.public_route_table_id,
    module.vpc_prod.private_route_table_id
  ]

  tags = {
    Name = "solarway-s3-endpoint"
    Environment = "prod"
  }
}

# -- Lambdas (Processamento do Data Lake) --------------------------------------

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Download das Lambdas do GitHub Releases (Triggers no apply)
resource "null_resource" "download_lambdas" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    # Em um ambiente de CI real, o download ocorreria na pipeline antes do terraform apply.
    # Usando curl com -f (fail silenciosamente no HTTP error) e removendo o arquivo em caso de falha.
    command = "curl -f -L -o ${path.module}/.terraform/raw_to_refined.zip https://github.com/Projeto-de-extensao-Grupo-06/data-analysis/releases/download/latest/raw_to_refined.zip || rm -f ${path.module}/.terraform/raw_to_refined.zip || del /f /q ${path.module}\\.terraform\\raw_to_refined.zip"
  }
}

resource "null_resource" "download_lambdas_trusted" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "curl -L -o ${path.module}/.terraform/trusted_to_refined.zip https://github.com/Projeto-de-extensao-Grupo-06/data-analysis/releases/download/latest/trusted_to_refined.zip || echo 'Falha ao baixar, verifique a URL'"
  }
}

# Upload dos binários para o S3 (Contorno do limite de 50MB da AWS API)
resource "aws_s3_object" "lambda_raw_to_trusted_zip" {
  depends_on = [null_resource.download_lambdas]
  bucket     = module.s3_raw.bucket_id
  key        = "lambdas/raw_to_refined.zip"
  source     = fileexists("${path.module}/.terraform/raw_to_refined.zip") ? "${path.module}/.terraform/raw_to_refined.zip" : "${path.module}/.terraform/lambda_dummy.zip"
}

resource "aws_s3_object" "lambda_trusted_to_refined_zip" {
  depends_on = [null_resource.download_lambdas_trusted]
  bucket     = module.s3_raw.bucket_id
  key        = "lambdas/trusted_to_refined.zip"
  source     = fileexists("${path.module}/.terraform/trusted_to_refined.zip") ? "${path.module}/.terraform/trusted_to_refined.zip" : "${path.module}/.terraform/lambda_dummy.zip"
}

# Criação das funções Lambda (utilizando S3)
resource "aws_lambda_function" "raw_to_trusted" {
  depends_on       = [aws_s3_object.lambda_raw_to_trusted_zip]
  function_name    = "solarway-raw-to-trusted"
  handler          = "main.handler"
  runtime          = "python3.9"
  role             = data.aws_iam_role.lab_role.arn
  s3_bucket        = module.s3_raw.bucket_id
  s3_key           = aws_s3_object.lambda_raw_to_trusted_zip.key
}

resource "aws_lambda_function" "trusted_to_refined" {
  depends_on       = [aws_s3_object.lambda_trusted_to_refined_zip]
  function_name    = "solarway-trusted-to-refined"
  handler          = "main.handler"
  runtime          = "python3.9"
  role             = data.aws_iam_role.lab_role.arn
  s3_bucket        = module.s3_raw.bucket_id
  s3_key           = aws_s3_object.lambda_trusted_to_refined_zip.key
}

# -- Grafana (Data Visualization) ----------------------------------------------
# Implementado como um container Docker em uma EC2 dedicada compartilhada (neste caso na subrede Innovation)
module "ec2_grafana" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "grafana-dashboard"
  instance_type        = "t3.micro"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[3] # Innovation/Workers subnet
  frontend_ports       = [3001]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    export BOT_TYPE="grafana"
    sed -i 's/\r$//' /tmp/setup-vm.sh
    bash /tmp/setup-vm.sh
  EOT
}

resource "aws_ssm_association" "env_grafana" {
  depends_on = [module.ec2_grafana]
  name       = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.ec2_grafana.instance_id]
  }

  parameters = {
    commands = "echo '${base64encode(join("\n", [for s in [
      "mkdir -p /tmp/solarway/services/grafana",
      "cat > /tmp/solarway/.env << 'ENVEOF'",
      "GRAFANA_USER=${var.grafana_user}",
      "GRAFANA_PASSWORD=${var.grafana_password}",
      "ENVEOF",
      "cat > /tmp/solarway/services/grafana/docker-compose.yml << 'COMPOSEEOF'",
      file("../../../services/grafana/docker-compose.yml"),
      "COMPOSEEOF",
      "cat > /tmp/solarway/setup-app.sh << 'EOF'",
      file("${path.module}/scripts/setup-bot.sh"),
      "EOF",
      "export BOT_TYPE='grafana'",
      "chmod +x /tmp/solarway/setup-app.sh",
      "sed -i 's/\\r$//' /tmp/solarway/setup-app.sh",
      "sudo -E bash /tmp/solarway/setup-app.sh"
    ] : replace(s, "\r", "")]))}' | base64 -d | bash"
  }
}
