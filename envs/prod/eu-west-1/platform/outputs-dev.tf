output "jobs_dev_queue_url" {
  value = data.aws_sqs_queue.jobs_dev.url
}

output "jobs_dev_queue_arn" {
  value = data.aws_sqs_queue.jobs_dev.arn
}

output "api_dev_irsa_role_arn" {
  value = module.api_irsa_dev.iam_role_arn
}

output "worker_dev_irsa_role_arn" {
  value = module.worker_irsa_dev.iam_role_arn
}
