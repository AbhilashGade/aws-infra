variable "vpc_cidr" {
  type        = string
  description = "CIDR for vpc in the given region"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "aws_profile" {
  type        = string
  description = "AWS Account profile"
}

variable "public_tag" {
  type        = string
  description = "public tag"
}

variable "public_subnet_name" {
  type        = string
  description = "public subnet name"
}

variable "private_tag" {
  type        = string
  description = "private subnet name"
}

variable "private_subnet_name" {
  type        = string
  description = "private subnet name"
}

variable "subnet_prefix" {
  type        = string
  description = "subnet prefix for all subnets under vpc 1"
}

variable "subnet_suffix" {
  type        = string
  description = "subnet suffix for all subnets under all vpcs"
}

variable "public_route_table_cidr" {
  type        = string
  description = "public route table CIDR for all ipv4"
}

variable "aws_keypair_dev" {
  description = " SSH keys to connect to EC2 Instance"
  default     = "aws-dev-kp"
}

variable "instance_type" {
  description = "instance type for EC2"
  default     = "t2.micro"
}

variable "security_group" {
  description = "Name of security group"
  default     = "application"
}

variable "ec2_tag_name" {
  description = "Tag Name of for EC2 instance"
  default     = "ec2-webapp-dev"
}

variable "latest_ami" {
  type        = string
  description = "Tag Name of for EC2 instance"
}

variable "DB_IDENTIFIER" {
  type = string
}

variable "DB_NAME" {
  type = string
}

variable "DB_USERNAME" {
  type = string
}
variable "DB_PASSWORD" {
  type = string
}

variable "DB_HOST" {
  type = string
}