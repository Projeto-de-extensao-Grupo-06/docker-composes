# monitoring.tf - PROD

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name  = "/cloudwatch-agent/prod/config"
  type  = "String"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    metrics = {
      namespace = "Custom/prod/EC2"
      metrics_collected = {
        cpu = {
          measurement                 = ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"]
          metrics_collection_interval = 60
          totalcpu                    = true
        }
        mem = {
          measurement                 = ["mem_used_percent", "mem_available_percent"]
          metrics_collection_interval = 60
        }
        disk = {
          measurement                 = ["used_percent", "inodes_free"]
          metrics_collection_interval = 60
          resources                   = ["/"]
        }
        netstat = {
          measurement                 = ["tcp_established", "tcp_time_wait"]
          metrics_collection_interval = 60
        }
      }
      append_dimensions = {
        InstanceId   = "$${aws:InstanceId}"
        InstanceType = "$${aws:InstanceType}"
        Environment  = "prod"
      }
    }
  })

  tags = {
    Environment = "prod"
  }
}

resource "aws_ssm_association" "install_cloudwatch_agent" {
  name = "AWS-ConfigureAWSPackage"

  targets {
    key    = "tag:Environment"
    values = ["prod"]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }
}

resource "aws_ssm_association" "start_cloudwatch_agent" {
  name       = "AmazonCloudWatch-ManageAgent"
  depends_on = [aws_ssm_association.install_cloudwatch_agent]

  targets {
    key    = "tag:Environment"
    values = ["prod"]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cloudwatch_agent_config.name
    optionalRestart               = "yes"
  }
}
