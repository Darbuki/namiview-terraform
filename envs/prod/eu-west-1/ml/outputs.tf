output "launch_template_id" {
  value = aws_launch_template.ml_train.id
}

output "launch_template_name" {
  value = aws_launch_template.ml_train.name
}

output "subnet_id" {
  value = aws_subnet.ml.id
}

output "training_role_arn" {
  value = aws_iam_role.ml_train.arn
}

output "ml_bucket" {
  value = var.ml_bucket
}

output "launch_hint" {
  value = "aws ec2 run-instances --launch-template LaunchTemplateName=${aws_launch_template.ml_train.name} --region ${var.region}"
}
