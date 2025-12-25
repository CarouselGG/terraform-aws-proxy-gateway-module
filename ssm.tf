# =============================================================================
# SSM Parameter Data Sources
# Reads Lambda route configurations from SSM parameters published by backend services
# =============================================================================

data "aws_ssm_parameter" "lambda_routes" {
  for_each = toset(var.lambda_route_ssm_parameters)

  name = each.value
}

locals {
  # Decode and merge all Lambda routes from SSM parameters
  # Each parameter contains JSON: { "GET /path": "arn:aws:lambda:...", ... }
  all_lambda_routes = merge([
    for param_name, param in data.aws_ssm_parameter.lambda_routes :
    jsondecode(nonsensitive(param.value))
  ]...)
}
