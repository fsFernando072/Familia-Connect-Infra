resource "aws_lb" "this" {
  name               = "lb-${var.name}"
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids
}

resource "aws_lb_target_group" "this" {
  name        = "tg-${var.name}"
  protocol    = "HTTP"
  port        = var.target_port
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path = var.health_check_path
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = var.target_instance_ids

  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value
  port             = var.target_port
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  protocol          = "HTTP"
  port              = var.listener_port

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
