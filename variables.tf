variable "location" {
  type = string
  default = "West Europe"
}

variable "prefix" {
  type = string
}

variable "openttd_allowed_ips" {
  default = ""
}
variable "openttd_admin_ips" {
  default = ""
}

variable "tags" {
  type = map(string)
}