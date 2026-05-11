# datalake.tf - PROD (Data Lake Domain: S3 + Lambdas + Grafana)

data "aws_caller_identity" "current" {}

# -- S3 Buckets (Data Lake Layers) ---------------------------------------------
module "s3_raw" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-raw-${data.aws_caller_identity.current.account_id}"
}

module "s3_trusted" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-trusted-${data.aws_caller_identity.current.account_id}"
}

module "s3_refined" {
  source = "../../modules/s3"

  environment = "prod"
  bucket_name = "solarway-datalake-refined-${data.aws_caller_identity.current.account_id}"
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

# Os ZIPs são pré-baixados pelo deploy-prod.ps1 antes do terraform apply/validate.
# GitHub Releases:
#   raw_to_trusted.zip   -> releases/download/latest/raw_to_trusted.zip
#   trusted_to_refined.zip -> releases/download/latest/trusted_to_refined.zip
locals {
  lambda_zips_dir = "${path.module}/.terraform/lambda_zips"
}

# Upload dos binários para o S3 (ZIPs ~59MB — acima do limite direto da API Lambda)
resource "aws_s3_object" "lambda_raw_to_trusted_zip" {
  bucket = module.s3_raw.bucket_id
  key    = "lambdas/raw_to_trusted.zip"
  source = "${local.lambda_zips_dir}/raw_to_trusted.zip"
  etag   = filemd5("${local.lambda_zips_dir}/raw_to_trusted.zip")
}

resource "aws_s3_object" "lambda_trusted_to_refined_zip" {
  bucket = module.s3_raw.bucket_id
  key    = "lambdas/trusted_to_refined.zip"
  source = "${local.lambda_zips_dir}/trusted_to_refined.zip"
  etag   = filemd5("${local.lambda_zips_dir}/trusted_to_refined.zip")
}

# Funções Lambda
resource "aws_lambda_function" "raw_to_trusted" {
  depends_on       = [aws_s3_object.lambda_raw_to_trusted_zip]
  function_name    = "solarway-raw-to-trusted"
  handler          = "main.handler"
  runtime          = "python3.9"
  role             = data.aws_iam_role.lab_role.arn
  s3_bucket        = module.s3_raw.bucket_id
  s3_key           = aws_s3_object.lambda_raw_to_trusted_zip.key
  source_code_hash = filebase64sha256("${local.lambda_zips_dir}/raw_to_trusted.zip")

  environment {
    variables = {
      TRUSTED_BUCKET = module.s3_trusted.bucket_id
    }
  }
}

resource "aws_lambda_function" "trusted_to_refined" {
  depends_on       = [aws_s3_object.lambda_trusted_to_refined_zip]
  function_name    = "solarway-trusted-to-refined"
  handler          = "main.handler"
  runtime          = "python3.9"
  role             = data.aws_iam_role.lab_role.arn
  s3_bucket        = module.s3_raw.bucket_id
  s3_key           = aws_s3_object.lambda_trusted_to_refined_zip.key
  source_code_hash = filebase64sha256("${local.lambda_zips_dir}/trusted_to_refined.zip")

  environment {
    variables = {
      REFINED_BUCKET = module.s3_refined.bucket_id
    }
  }
}

# -- Gatilhos S3 -> Lambda -------------------------------------------------------

# Permissão para o S3 invocar a Lambda raw_to_trusted
resource "aws_lambda_permission" "allow_s3_raw" {
  statement_id  = "AllowS3Raw"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.raw_to_trusted.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3_raw.bucket_arn
}

# Permissão para o S3 invocar a Lambda trusted_to_refined
resource "aws_lambda_permission" "allow_s3_trusted" {
  statement_id  = "AllowS3Trusted"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trusted_to_refined.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3_trusted.bucket_arn
}

# Gatilho: upload no bucket RAW -> dispara raw_to_trusted
resource "aws_s3_bucket_notification" "raw_trigger" {
  depends_on = [aws_lambda_permission.allow_s3_raw]
  bucket     = module.s3_raw.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.raw_to_trusted.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
  }
}

# Gatilho: upload no bucket TRUSTED -> dispara trusted_to_refined
resource "aws_s3_bucket_notification" "trusted_trigger" {
  depends_on = [aws_lambda_permission.allow_s3_trusted]
  bucket     = module.s3_trusted.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trusted_to_refined.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "trusted/"
  }
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
