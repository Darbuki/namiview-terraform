variable "region" {
  type    = string
  default = "eu-west-1"
}

# g4dn spot capacity varies by AZ; flip this if launches start failing
# with InsufficientInstanceCapacity.
variable "az" {
  type    = string
  default = "eu-west-1a"
}

variable "instance_type" {
  type    = string
  default = "g4dn.xlarge" # 4 vCPU / 16GB / T4 16GB — ~$0.2/h spot
}

variable "root_volume_gb" {
  type    = number
  default = 100
}

# Hard watchdog: the instance powers itself off after this many minutes
# even if training hangs. Spot + terminate-on-shutdown = nothing lingers.
variable "max_run_minutes" {
  type    = number
  default = 480
}

variable "ml_bucket" {
  type    = string
  default = "namiview-ml" # created in foundation/buckets-ml.tf
}
