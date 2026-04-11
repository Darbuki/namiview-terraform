output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.namiview-prod-bucket.bucket
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.eks.arn
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
