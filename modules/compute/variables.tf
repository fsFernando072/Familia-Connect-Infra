variable "instances" {
  description = <<-EOT
    Mapa de instâncias EC2 a criar. A chave do mapa vira o nome lógico
    do recurso (ex: "front_a", "back_b", "db"). O campo "user_data"
    é o conteúdo do script (.sh) que cada instância deve rodar no boot
    — é aqui que se garante que instâncias de front rodam config_front.sh,
    as de back rodam config_back.sh, e a de db roda config_db.sh.
  EOT
  type = map(object({
    ami_id               = string
    instance_type        = string
    key_name             = string
    subnet_id            = string
    security_group_ids   = list(string)
    iam_instance_profile = string
    user_data            = string
    name_tag             = string
    associate_eip        = bool
    private_ip           = optional(string)
  }))
}
