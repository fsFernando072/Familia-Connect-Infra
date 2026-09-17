resource "aws_instance" "this" {
  for_each = var.instances

  ami                    = each.value.ami_id
  instance_type          = each.value.instance_type
  key_name               = each.value.key_name
  subnet_id              = each.value.subnet_id
  private_ip             = try(each.value.private_ip, null)
  vpc_security_group_ids = each.value.security_group_ids
  iam_instance_profile   = each.value.iam_instance_profile

  user_data                   = each.value.user_data
  user_data_replace_on_change = true

  tags = {
    Name = each.value.name_tag
  }
}

resource "aws_eip" "this" {
  for_each = { for k, v in var.instances : k => v if v.associate_eip }

  domain   = "vpc"
  instance = aws_instance.this[each.key].id

  tags = {
    Name = "${var.instances[each.key].name_tag}-eip"
  }
}
