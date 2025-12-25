# =============================================================================
# Custom Domain and DNS Configuration
# =============================================================================

# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name       = var.custom_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

# DNS Validation Record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# API Gateway Custom Domain
resource "aws_apigatewayv2_domain_name" "main" {
  domain_name = var.custom_domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.main.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  depends_on = [aws_acm_certificate_validation.main]

  tags = local.common_tags
}

# API Mapping
resource "aws_apigatewayv2_api_mapping" "main" {
  api_id          = aws_apigatewayv2_api.proxy.id
  domain_name     = aws_apigatewayv2_domain_name.main.domain_name
  stage           = aws_apigatewayv2_stage.main.id
  api_mapping_key = ""
}

# Route 53 A Record
resource "aws_route53_record" "api" {
  zone_id = var.hosted_zone_id
  name    = var.custom_domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.main.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
