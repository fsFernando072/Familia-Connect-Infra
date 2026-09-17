resource "awscc_s3_bucket" "this" {
  for_each = var.bucket_names

  bucket_name = each.value

  tags = [
    {
      key   = "Name"
      value = each.value
    },
    {
      key   = "Layer"
      value = each.key
    }
  ]
}