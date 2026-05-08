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

# -- Lambdas (Placeholder / Structure) -----------------------------------------
# Aqui ficariam os gatilhos de processamento entre as camadas do bucket.
# Por enquanto, mantemos a estrutura para expansão futura.

# resource "aws_lambda_function" "ingestion_processor" {
#   ...
# }

# -- Grafana (Data Visualization) ----------------------------------------------
# Implementado como um container Docker em uma EC2 dedicada ou compartilhada.
# Por simplicidade, pode ser adicionado à pilha de 'Innovation' ou ter sua própria EC2.

module "ec2_grafana" {
  source = "../../modules/ec2"

  environment          = "prod"
  instance_name        = "grafana-dashboard"
  instance_type        = "t3.micro"
  vpc_id               = module.vpc_prod.vpc_id
  subnet_id            = module.vpc_prod.private_subnet_ids[3] # Innovation/Workers subnet
  frontend_ports       = [3000]
  allowed_cidr_blocks  = ["10.0.0.0/24"]
  iam_instance_profile = "LabInstanceProfile"
  user_data = <<-EOT
    #!/bin/bash
    base64 -d << 'EOF' > /tmp/setup-vm.sh
    ${base64encode(file("../../../scripts/setup-vm.sh"))}
    EOF
    bash /tmp/setup-vm.sh
    # Grafana Setup via Docker
    sudo docker run -d --name=grafana -p 3000:3000 grafana/grafana
  EOT
}
