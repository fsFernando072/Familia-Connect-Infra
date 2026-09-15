output "front_sg_id" {
  value = aws_security_group.front.id
}

output "back_sg_id" {
  value = aws_security_group.back.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}
