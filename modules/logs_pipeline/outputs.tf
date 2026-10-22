output "database_name" {
  value = aws_glue_catalog_database.logs.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.logs.name
}

output "glue_job_name" {
  value = aws_glue_job.bronze_to_silver.name
}

output "bronze_table" {
  value = "${aws_glue_catalog_database.logs.name}.${aws_glue_catalog_table.logs_bronze.name}"
}

output "silver_table" {
  value = "${aws_glue_catalog_database.logs.name}.${aws_glue_catalog_table.logs_silver.name}"
}
