# ---------------------------------------------------------------------
# Alarmes CloudWatch — CPU (todas as instâncias)
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = var.cpu_instance_ids

  alarm_name          = "${each.value}-CPUUtilization-High"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------------------------------------
# Alarmes CloudWatch — Network In/Out (instâncias FRONT)
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "network_in_front" {
  for_each = var.front_instance_ids

  alarm_name          = "${each.value}-NetworkIn-High"
  namespace           = "AWS/EC2"
  metric_name         = "NetworkIn"
  statistic           = "Sum"
  period              = 300
  threshold           = 100000000
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "network_out_front" {
  for_each = var.front_instance_ids

  alarm_name          = "${each.value}-NetworkOut-High"
  namespace           = "AWS/EC2"
  metric_name         = "NetworkOut"
  statistic           = "Sum"
  period              = 300
  threshold           = 100000000
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------------------------------------
# Alarmes CloudWatch — Load Balancer BACK
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lb_back_latency" {
  alarm_name          = "lb-back-TargetResponseTime-High"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  statistic           = "Average"
  period              = 300
  threshold           = 2
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  dimensions = {
    LoadBalancer = var.lb_back_full_name
    TargetGroup  = var.tg_back_full_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "tg_back_healthy_hosts" {
  alarm_name          = "tg-back-HealthyHostCount-Low"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Average"
  period              = 300
  threshold           = 1
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1

  dimensions = {
    LoadBalancer = var.lb_back_full_name
    TargetGroup  = var.tg_back_full_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------------------------------------
# Alarme CloudWatch — Disco do banco (requer CloudWatch Agent na VM)
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "db_disk_used" {
  alarm_name          = "ec2-db-disk-used-percent-high"
  namespace           = "CWAgent"
  metric_name         = "disk_used_percent"
  statistic           = "Average"
  period              = 300
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2

  dimensions = {
    InstanceId = var.db_instance_id
    path       = "/"
    fstype     = "ext4"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---------------------------------------------------------------------
# Alarmes CloudWatch — Buckets S3
# ---------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "bucket_size" {
  for_each = var.bucket_names

  alarm_name          = "${each.value}-BucketSizeBytes-High"
  namespace           = "AWS/S3"
  metric_name         = "BucketSizeBytes"
  statistic           = "Average"
  period              = 86400
  threshold           = 5000000000
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1

  dimensions = {
    BucketName  = each.value
    StorageType = "StandardStorage"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
