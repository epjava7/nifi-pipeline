
output "cluster_name" {
  description = "eks cluster name"
  value = aws_eks_cluster.this.name
}

output "efs_id" {
  description = "efs filesystem id"
  value = aws_efs_file_system.nifi.id
}

output "vpc_id" {
  description = "vpc id"
  value = aws_vpc.this.id
}