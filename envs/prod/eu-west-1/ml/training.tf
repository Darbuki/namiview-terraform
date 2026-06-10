# AWS Deep Learning Base AMI (Ubuntu 22.04, NVIDIA driver + CUDA preinstalled).
# Published SSM parameter — always resolves to the latest revision at plan time.
data "aws_ssm_parameter" "dlami" {
  name = "/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-22.04/latest/ami-id"
}

# The rig is a launch template, not a running instance: each training run is a
# one-shot spot launch (Phase 2 adds the launcher workflow), the instance pulls
# code+data from s3://namiview-ml, trains, syncs results back, and powers off —
# spot one-time + terminate-on-shutdown means it ceases to exist. Idle cost: $0.
resource "aws_launch_template" "ml_train" {
  name                   = "namiview-ml-train"
  update_default_version = true

  image_id      = data.aws_ssm_parameter.dlami.insecure_value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ml_train.arn
  }

  network_interfaces {
    subnet_id                   = aws_subnet.ml.id
    security_groups             = [aws_security_group.ml_train.id]
    associate_public_ip_address = true
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
    }
  }

  instance_initiated_shutdown_behavior = "terminate"

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_gb
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tftpl", {
    bucket          = var.ml_bucket
    max_run_minutes = var.max_run_minutes
  }))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "namiview-ml-train"
      Project = "namiview"
      Layer   = "ml"
    }
  }
}
