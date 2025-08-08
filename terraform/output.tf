output "cluster_name" { 
    value = aws_eks_cluster.this.name 
}

output "efs_id" {
  description = "efs id"
  value       = aws_efs_file_system.nifi.id
}