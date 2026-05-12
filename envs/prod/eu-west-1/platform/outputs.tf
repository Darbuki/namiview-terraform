output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.namiview-prod-bucket.bucket
}

output "loki_bucket_name" {
  value = aws_s3_bucket.loki.bucket
}

output "loki_irsa_role_arn" {
  value = module.loki_irsa.iam_role_arn
}

output "jobs_queue_url" {
  value = aws_sqs_queue.jobs.url
}

output "jobs_queue_arn" {
  value = aws_sqs_queue.jobs.arn
}

output "worker_irsa_role_arn" {
  value = module.worker_irsa.iam_role_arn
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.eks.arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_gateway_public_ip" {
  description = "NAT gateway public IP — add to MongoDB Atlas IP Access List"
  value       = module.vpc.nat_public_ips[0]
}

output "acm_dns_validation_records" {
  description = "DNS records to create in Cloudflare for ACM validation"
  value = {
    for dvo in aws_acm_certificate.eks.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
