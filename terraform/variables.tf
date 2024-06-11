
variable "prefix" {
  description = "prefix"
  type=string
  default = "steven"
}

variable "controllerip" {
  description = "the ipaddress for accessing bastion server"
  type=string
  default="*"
}