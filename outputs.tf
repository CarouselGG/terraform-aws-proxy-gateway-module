# =============================================================================
# API Gateway Outputs
# =============================================================================

output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.proxy.id
}

output "api_endpoint" {
  description = "Default endpoint URL of the API Gateway"
  value       = aws_apigatewayv2_api.proxy.api_endpoint
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway (for Lambda permissions)"
  value       = aws_apigatewayv2_api.proxy.execution_arn
}

output "stage_id" {
  description = "ID of the API Gateway stage"
  value       = aws_apigatewayv2_stage.main.id
}

output "stage_invoke_url" {
  description = "Invoke URL for the stage"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

# =============================================================================
# Custom Domain Outputs
# =============================================================================

output "custom_domain_name" {
  description = "Custom domain name"
  value       = aws_apigatewayv2_domain_name.main.domain_name
}

output "custom_domain_target" {
  description = "Target domain name for the custom domain"
  value       = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].target_domain_name
}

output "custom_domain_hosted_zone_id" {
  description = "Hosted zone ID for the custom domain"
  value       = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].hosted_zone_id
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

# =============================================================================
# VPC Outputs (only when create_vpc = true)
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC (null if create_vpc = false)"
  value       = var.create_vpc ? aws_vpc.main[0].id : null
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = var.create_vpc ? aws_vpc.main[0].cidr_block : null
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = var.create_vpc ? aws_subnet.public[*].id : []
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = var.create_vpc ? aws_subnet.private[*].id : []
}

output "nat_gateway_ips" {
  description = "Elastic IPs of NAT gateways"
  value       = var.create_vpc && var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# =============================================================================
# Route Information
# =============================================================================

output "lambda_route_count" {
  description = "Number of Lambda routes configured"
  value       = length(local.all_lambda_routes)
}

output "http_proxy_route_count" {
  description = "Number of HTTP proxy routes configured"
  value       = length(var.http_proxy_routes)
}

output "lambda_routes" {
  description = "Map of Lambda route keys to their integration IDs"
  value       = { for k, v in aws_apigatewayv2_route.lambda : k => v.id }
}

# =============================================================================
# Logging Outputs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.arn
}

# =============================================================================
# Authorizer Outputs
# =============================================================================

output "authorizer_id" {
  description = "ID of the JWT authorizer (null if not enabled)"
  value       = var.enable_jwt_authorizer ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

output "authorizer_name" {
  description = "Name of the JWT authorizer (null if not enabled)"
  value       = var.enable_jwt_authorizer ? aws_apigatewayv2_authorizer.jwt[0].name : null
}
