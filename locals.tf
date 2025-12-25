locals {
  # Merge all tags
  common_tags = merge(var.tags, {
    Module      = "terraform-aws-proxy-gateway-module"
    ManagedBy   = "Terraform"
    Environment = var.stage_name
  })

  # Determine availability zones
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available[0].names, 0, 2)
}

# Get available AZs if not specified
data "aws_availability_zones" "available" {
  count = length(var.availability_zones) == 0 && var.create_vpc ? 1 : 0
  state = "available"
}
