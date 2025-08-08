# eks cluster

resource "aws_eks_cluster" "this" {
  name = "nifi-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version = "1.30"

  vpc_config {
    subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    endpoint_public_access = true
    endpoint_private_access = false
  }
}

resource "aws_eks_node_group" "default" {
  cluster_name = aws_eks_cluster.this.name
  node_group_name = "nodegroup-ec2"
  node_role_arn = aws_iam_role.eks_node.arn

  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  scaling_config {
    desired_size = 2
    max_size = 2
    min_size = 1
  }

  instance_types = ["t3.small"]
  ami_type = "AL2_x86_64"
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name = aws_eks_cluster.this.name
  addon_name = "aws-efs-csi-driver"
}

# iam

resource "aws_iam_role" "eks_cluster" {
  name = "eksClusterRole"
  assume_role_policy = data.aws_iam_policy_document.eks_trust.json
}

data "aws_iam_policy_document" "eks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "eks_node" {
  name = "eksNodeRole"
  assume_role_policy = data.aws_iam_policy_document.eks_node_trust.json
}

resource "aws_iam_role_policy_attachment" "node_efs" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

data "aws_iam_policy_document" "eks_node_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# networking

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "nifi-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-1c"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "pub_b" {
  subnet_id = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private_a" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.101.0/24"
  availability_zone = "us-west-1a"
  tags = { Name = "nifi-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id = aws_vpc.this.id
  cidr_block = "10.0.102.0/24"
  availability_zone = "us-west-1c"
  tags = { Name = "nifi-private-b" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "nat-gateway-eip" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.this.id

  depends_on = [
    aws_nat_gateway.gw
  ]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }
}

resource "aws_route_table_association" "priv_a" {
  subnet_id = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "priv_b" {
  subnet_id = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# efs

resource "aws_efs_file_system" "nifi" {
  lifecycle_policy { transition_to_ia = "AFTER_30_DAYS" }
  throughput_mode = "bursting"
  tags = { Name = "nifi-efs" }
}

resource "aws_efs_mount_target" "a" {
  file_system_id = aws_efs_file_system.nifi.id
  subnet_id = aws_subnet.public_a.id
  security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
}
resource "aws_efs_mount_target" "c" {
  file_system_id = aws_efs_file_system.nifi.id
  subnet_id = aws_subnet.public_b.id
  security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
}