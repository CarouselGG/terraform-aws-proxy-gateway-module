# =============================================================================
# JWT Authorizer for Auth0/OAuth2.0
# =============================================================================

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.enable_jwt_authorizer ? 1 : 0

  api_id           = aws_apigatewayv2_api.proxy.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.api_name}-jwt-authorizer"

  jwt_configuration {
    audience = var.jwt_audience
    issuer   = var.jwt_issuer
  }
}

locals {
  # Determine which routes need authorization
  public_route_set = toset(var.public_routes)
}
