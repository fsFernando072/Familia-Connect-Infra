output "front_sg_id" { value = aws_security_group.front.id }
output "front_alb_sg_id" { value = aws_security_group.front_alb.id }
output "back_sg_id" { value = aws_security_group.back.id }
output "back_alb_sg_id" { value = aws_security_group.back_alb.id }
output "ocr_sg_id" { value = aws_security_group.ocr.id }
output "ocr_alb_sg_id" { value = aws_security_group.ocr_alb.id }
output "db_sg_id" { value = aws_security_group.db.id }
