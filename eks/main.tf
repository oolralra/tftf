module "min-eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.26.6"
  cluster_name    = "min-cluster-test"
  cluster_version = "1.29"
  # k8s version

  #cluster_security_group_id = var.min-pri-sg-id
  # node_security_group_id = var.min-pub-sg-id
  # security group 설정

  vpc_id          = var.min-vpc-id
  # vpc id

  subnet_ids = [
    var.pri-sub1-id,
    var.pri-sub2-id
  ]
  # 클러스터의 subnet 설정

  eks_managed_node_groups = {
    min_node_group = {
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.micro"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }

  cluster_endpoint_private_access = true
  # cluster를 private sub에 만듬
}

data "aws_eks_cluster_auth" "this" {
  name = "min-cluster-test"
}

provider "kubernetes" {
  host                   = module.min-eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.min-eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  
}

provider "helm" {
  kubernetes {
    host                   = module.min-eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.min-eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
  
}
