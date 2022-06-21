variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "ami" {
  type    = string
  default = "ami-067f8db0a5c2309c0"
}

variable "vlad_vpc_cidr" {
  type = string
  default = "172.16.0.0/22"
}
variable "vlad_public_subnets" {
  type = string
  default ="172.16.1.0/24"
}
variable "vlad_private_subnets" {
  type = string
  default = "172.16.2.0/24"
}
