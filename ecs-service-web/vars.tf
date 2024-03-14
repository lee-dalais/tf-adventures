variable "whitelist_cidr_block" {
  type    = string
  default = "REPLACE-ME"
}

variable "app" {
  type    = string
  default = "ecs"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "usw2"
}

variable "lb_port" {
  type    = number
  default = 80
}