output "workgroup_name" {
  value = aws_athena_workgroup.this.name
}

output "results_location" {
  value = local.results_location
}

output "export_location" {
  value = local.export_location
}
