provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  route {
    cidr_block = var.vpc_cidr
    gateway_id = "local"
  }
}

resource "aws_route_table_association" "subnet_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_3" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.main.id
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_1_cidr
  availability_zone       = var.subnet_1_az
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_2_cidr
  availability_zone       = var.subnet_2_az
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_3_cidr
  availability_zone       = var.subnet_3_az
  map_public_ip_on_launch = true
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"
  
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  
  cluster_endpoint_public_access = true
  
  vpc_id                   = aws_vpc.main.id
  subnet_ids               = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  control_plane_subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id, aws_subnet.subnet_3.id]
  
  eks_managed_node_groups = {
    green = {
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      desired_size   = var.node_group_desired_size
      instance_types = [var.node_group_instance_type]
    }
  }
}

resource "aws_ecr_repository" "microservice_a" {
  name = var.ecr_repo_a_name
}

resource "aws_ecr_repository" "microservice_b" {
  name = var.ecr_repo_b_name
}

output "ecr_repository_url_microservice_a" {
  value = aws_ecr_repository.microservice_a.repository_url
}

output "ecr_repository_url_microservice_b" {
  value = aws_ecr_repository.microservice_b.repository_url
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}