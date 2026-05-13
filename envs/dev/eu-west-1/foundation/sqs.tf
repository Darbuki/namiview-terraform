resource "aws_sqs_queue" "jobs_dlq" {
  name                      = "namiview-prod-dev-jobs-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "jobs" {
  name                       = "namiview-prod-dev-jobs"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 3
  })
}
