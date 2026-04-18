# Triển khai Amazon EKS bằng Terraform

Thư mục này dùng Terraform để tạo cụm Kubernetes trên AWS EKS.

## 1) Cấu trúc thư mục

- `eks-cluster/main.tf`: tài nguyên Terraform chính.
- `eks-cluster/variables.tf`: biến đầu vào.

## 2) Yêu cầu trước khi chạy

- AWS account + IAM quyền tạo EKS/VPC/EC2/IAM role liên quan.
- Cài `terraform` và `awscli`.
- Đã cấu hình credentials:

```bash
aws configure
```

## 3) Quy trình chuẩn

```bash
cd eks-cluster
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tf.plan
terraform apply tf.plan
```

## 4) Lấy kubeconfig

Sau khi tạo cluster thành công:

```bash
aws eks update-kubeconfig --region <aws-region> --name <cluster-name>
kubectl get nodes
```

## 5) Hủy môi trường (khi không dùng)

```bash
cd eks-cluster
terraform destroy
```

> Lưu ý chi phí: EKS và tài nguyên đi kèm phát sinh phí theo giờ.
