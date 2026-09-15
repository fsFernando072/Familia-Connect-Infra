resource "aws_s3_bucket" "this" {
  for_each = var.bucket_names

  bucket = each.value

  tags = {
    Name  = each.value
    Layer = each.key
  }
}
