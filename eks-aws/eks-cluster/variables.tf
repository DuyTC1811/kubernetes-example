variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_1_cidr" {
  description = "CIDR block for subnet 1"
  type        = string
  default     = "10.0.0.0/20"
}

variable "subnet_2_cidr" {
  description = "CIDR block for subnet 2"
  type        = string
  default     = "10.0.16.0/20"
}

variable "subnet_3_cidr" {
  description = "CIDR block for subnet 3"
  type        = string
  default     = "10.0.32.0/20"
}

variable "subnet_1_az" {
  description = "Availability zone for subnet 1"
  type        = string
  default     = "us-east-1b"
}

variable "subnet_2_az" {
  description = "Availability zone for subnet 2"
  type        = string
  default     = "us-east-1c"
}

variable "subnet_3_az" {
  description = "Availability zone for subnet 3"
  type        = string
  default     = "us-east-1d"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-cluster-eks"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31.1"
}

variable "node_group_min_size" {
  description = "Minimum size of the node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum size of the node group"
  type        = number
  default     = 1
}

variable "node_group_desired_size" {
  description = "Desired size of the node group"
  type        = number
  default     = 1
}

variable "node_group_instance_type" {
  description = "EC2 instance type for the node group"
  type        = string
  default     = "t3.medium"
}

variable "ecr_repo_a_name" {
  description = "Name of the first ECR repository"
  type        = string
  default     = "microservice-a"
}

variable "ecr_repo_b_name" {
  description = "Name of the second ECR repository"
  type        = string
  default     = "microservice-b"
}