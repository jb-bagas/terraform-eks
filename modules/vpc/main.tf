locals {
  # Carve /20 subnets out of the /16 VPC CIDR. Each AZ gets one public and
  # one private subnet; the private block is offset by the number of AZs.
  public_subnet_cidrs  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i + length(var.azs))]

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# ─────────────────────────────────────────────
# VPC FLOW LOGS
# ─────────────────────────────────────────────
resource "aws_flow_log" "this" {
  count                = var.enable_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.vpc_flow_logs[0].arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.cluster_name}"
  retention_in_days = var.flow_log_retention_days
  tags              = local.common_tags
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.cluster_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.cluster_name}-vpc-flow-logs-policy"
  role  = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = [
          aws_cloudwatch_log_group.vpc_flow_logs[0].arn,
          "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
        ]
      },
      {
        Action   = ["logs:DescribeLogGroups"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# INTERNET GATEWAY
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# ─────────────────────────────────────────────
# PUBLIC SUBNETS
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────
# PRIVATE SUBNETS
# ─────────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# ─────────────────────────────────────────────
# NAT GATEWAY (single for cost, one per AZ for prod)
# ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.single_nat_gateway ? aws_subnet.public[0].id : aws_subnet.public[count.index].id

  connectivity_type = "public"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
