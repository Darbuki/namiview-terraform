# Minimal self-contained network: one public subnet, IGW, no NAT (free).
# The EKS-era VPC is gone and we don't assume a default VPC exists.

resource "aws_vpc" "ml" {
  cidr_block           = "10.99.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "namiview-ml" }
}

resource "aws_internet_gateway" "ml" {
  vpc_id = aws_vpc.ml.id

  tags = { Name = "namiview-ml" }
}

resource "aws_subnet" "ml" {
  vpc_id                  = aws_vpc.ml.id
  cidr_block              = "10.99.0.0/25"
  availability_zone       = var.az
  map_public_ip_on_launch = true

  tags = { Name = "namiview-ml" }
}

resource "aws_route_table" "ml" {
  vpc_id = aws_vpc.ml.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ml.id
  }

  tags = { Name = "namiview-ml" }
}

resource "aws_route_table_association" "ml" {
  subnet_id      = aws_subnet.ml.id
  route_table_id = aws_route_table.ml.id
}

# Egress-only: no inbound at all — debugging goes through SSM, not SSH.
resource "aws_security_group" "ml_train" {
  name        = "namiview-ml-train"
  description = "namiview ML training instance (egress only)"
  vpc_id      = aws_vpc.ml.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "namiview-ml-train" }
}
