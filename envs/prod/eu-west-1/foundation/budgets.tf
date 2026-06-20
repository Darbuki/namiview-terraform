# Cost guardrail for the S3 spend driven by Loki (chunk/index PUTs + the
# on-prem query egress path). Storage itself is capped by the 2-day lifecycle
# on the loki bucket, so this budget exists to catch a *runaway* — e.g. a
# Loki flush loop hammering PutObject, or a query storm egressing chunks to
# the homelab — that the lifecycle rule does not bound. $20/mo is ~6x the
# expected steady-state, so it only alerts on something genuinely wrong.
#
# Scoped to the S3 service (S3 request + data-transfer-out charges bill under
# S3), not account-wide, so the threshold stays meaningful regardless of other
# AWS spend. AWS Budgets emails subscribers directly (no SNS topic needed).
resource "aws_budgets_budget" "s3_monthly" {
  name         = "namiview-s3-monthly"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = ["Amazon Simple Storage Service"]
  }

  # Fires once actual S3 spend crosses 80% of the cap ($16) within the month.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.cost_alert_emails
  }

  # Fires early in the month if the run rate is forecast to exceed the cap —
  # catches a runaway days before it actually rings up the full bill.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.cost_alert_emails
  }
}
