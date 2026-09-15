locals {
  cpu_metrics = [
    for k, id in var.cpu_instance_ids : ["AWS/EC2", "CPUUtilization", "InstanceId", id]
  ]

  network_metrics = flatten([
    for k, id in var.front_instance_ids : [
      ["AWS/EC2", "NetworkIn", "InstanceId", id],
      ["AWS/EC2", "NetworkOut", "InstanceId", id],
    ]
  ])

  bucket_metrics = [
    for k, name in var.bucket_names : ["AWS/S3", "BucketSizeBytes", "BucketName", name, "StorageType", "StandardStorage"]
  ]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Utilização de CPU EC2"
          region  = var.region
          stat    = "Average"
          period  = 300
          metrics = local.cpu_metrics
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Network Front-end"
          region  = var.region
          stat    = "Sum"
          period  = 300
          metrics = local.network_metrics
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Load Balancer"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.lb_back_full_name, "TargetGroup", var.tg_back_full_name],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.lb_back_full_name, "TargetGroup", var.tg_back_full_name],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Disco Banco de Dados"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            ["CWAgent", "disk_used_percent", "InstanceId", var.db_instance_id, "path", "/", "fstype", "ext4"],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title   = "Buckets S3"
          region  = var.region
          stat    = "Average"
          period  = 86400
          metrics = local.bucket_metrics
        }
      },
    ]
  })
}
