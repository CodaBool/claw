# variable "name" {
#   type = string
# }

variable "key_name" {
  type    = string
  default = "win"
}

variable "ssh_ip" {
  type    = string
  default = "107.200.81.38/32"
}

# variable "ip" {
#   type = string
# }
# variable "subnet" {
#   type = string
# }

variable "instance_type" {
  type    = string
  default = "t4g.nano"
}
