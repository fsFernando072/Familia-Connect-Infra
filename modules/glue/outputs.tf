output "job_name" {
  value = aws_glue_job.bronze_para_silver.name
}

output "crawler_name" {
  value = try(aws_glue_crawler.silver[0].name, null)
}

output "database_name" {
  value = try(aws_glue_catalog_database.silver[0].name, null)
}
