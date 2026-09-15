output "dns_name" {
  value = aws_lb.this.dns_name
}

output "arn" {
  value = aws_lb.this.arn
}

output "lb_full_name" {
  description = "Usado como dimensão LoadBalancer nos alarmes/dashboard do CloudWatch"
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "tg_full_name" {
  description = "Usado como dimensão TargetGroup nos alarmes/dashboard do CloudWatch"
  value       = aws_lb_target_group.this.arn_suffix
}
