output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "back_subnet_a_id" {
  value = aws_subnet.back_a.id
}

output "back_subnet_b_id" {
  value = aws_subnet.back_b.id
}

output "db_subnet_a_id" {
  value = aws_subnet.db_a.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}
