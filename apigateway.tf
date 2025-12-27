# =============================================================================
# API Gateway HTTP API
# =============================================================================

resource "aws_apigatewayv2_api" "proxy" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = var.api_description

  dynamic "cors_configuration" {
    for_each = var.cors_configuration != null ? [var.cors_configuration] : []
    content {
      allow_origins     = cors_configuration.value.allow_origins
      allow_methods     = cors_configuration.value.allow_methods
      allow_headers     = cors_configuration.value.allow_headers
      expose_headers    = cors_configuration.value.expose_headers
      allow_credentials = cors_configuration.value.allow_credentials
      max_age           = cors_configuration.value.max_age
    }
  }

  tags = local.common_tags
}

# =============================================================================
# Lambda Integrations (Direct Invocation)
# =============================================================================

resource "aws_apigatewayv2_integration" "lambda" {
  for_each = local.all_lambda_routes

  api_id                 = aws_apigatewayv2_api.proxy.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda" {
  for_each = local.all_lambda_routes

  api_id    = aws_apigatewayv2_api.proxy.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"

  # Apply JWT authorization unless route is in public_routes list
  authorization_type = var.enable_jwt_authorizer && !contains(var.public_routes, each.key) ? "JWT" : "NONE"
  authorizer_id      = var.enable_jwt_authorizer && !contains(var.public_routes, each.key) ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

# =============================================================================
# HTTP Proxy Integrations (Non-migrated Services)
# =============================================================================

resource "aws_apigatewayv2_integration" "http_proxy" {
  for_each = var.http_proxy_routes

  api_id             = aws_apigatewayv2_api.proxy.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = each.value.target_url
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "http_proxy" {
  for_each = var.http_proxy_routes

  api_id    = aws_apigatewayv2_api.proxy.id
  route_key = "ANY /${each.value.path_prefix}/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.http_proxy[each.key].id}"

  # HTTP proxy routes can also use JWT authorization
  authorization_type = var.enable_jwt_authorizer ? "JWT" : "NONE"
  authorizer_id      = var.enable_jwt_authorizer ? aws_apigatewayv2_authorizer.jwt[0].id : null
}

# =============================================================================
# Stage Configuration
# =============================================================================

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.proxy.id
  name        = var.stage_name
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      caller             = "$context.identity.caller"
      user               = "$context.identity.user"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      resourcePath       = "$context.resourcePath"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationStatus  = "$context.integration.status"
      integrationLatency = "$context.integrationLatency"
    })
  }

  default_route_settings {
    throttling_burst_limit   = var.throttling_burst_limit
    throttling_rate_limit    = var.throttling_rate_limit
    detailed_metrics_enabled = true
  }

  tags = local.common_tags
}
