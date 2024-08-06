output "eks_cluster_endpoint" {
    value = module.min-eks.cluster_endpoint
} 
output "eks_cluster_certificate_authority_data" {
  value = module.min-eks.cluster_certificate_authority_data
}