variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  type        = string
  description = "VPC CIDR 범위"
}

variable "sn_cidr_pub" {
  default     = ["10.0.0.0/24", "10.0.2.0/24"]
  type        = list
  description = "Public Subnet CIDR 범위"
}

variable "sn_cidr_pri" {
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
  type        = list
  description = "Private Subnet CIDR 범위"
}

variable "sn_cidr_db" {
  default     = ["10.0.4.0/24", "10.0.5.0/24"]
  type        = list
  description = "DB Subnet CIDR 범위"
}

variable "availability_zones" {
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
  type        = list
  description = "사용할 가용영역 범위"
}

variable "nat_count" {
  default     = 1
  type        = number
  description = "NAT GW 개수"
}

variable "bastion_count" {
  default     = 1
  type        = number
  description = "Bastion Host 개수"
}

variable "web_server_count" {
  default     = 2
  type        = number
  description = "Web Server Host 개수"
}

variable "az_for_name" {
  default     = ["a", "c"]
  type        = list
  description = "가용영역 별 서브넷 네임 태그를 위한 구분"
}