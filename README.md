# Terraform AWS Proxy Gateway Module

A production-ready Terraform module for creating a centralized API Gateway proxy that routes requests to multiple backend Lambda services using direct invocation.

## Created by Carousel

Author - [Loren M. Kerr](https://github.com/lmkerr 'Github Page for Loren M. Kerr')

## Features

- **Centralized Gateway** - Single entry point for all microservices
- **Direct Lambda Invocation** - Uses AWS_PROXY integration for optimal performance
- **Cross-Service Discovery** - Reads Lambda routes from SSM parameters
- **HTTP Proxy Support** - Routes for non-migrated services via HTTP_PROXY
- **Optional VPC** - Creates VPC with public/private subnets when needed
- **Custom Domains** - Automatic ACM certificate and Route 53 DNS
- **CORS Support** - Flexible cross-origin resource sharing
- **CloudWatch Logging** - Structured JSON access logs

## Architecture

```text
                                    +------------------+
                                    |   Route 53       |
                                    |   DNS Record     |
                                    +--------+---------+
                                             |
                                    +--------v---------+
                                    |  ACM Certificate |
                                    +--------+---------+
                                             |
+-------------+                     +--------v---------+
|   Client    | ------------------> |  Proxy Gateway   |
+-------------+        HTTPS        |  (HTTP API v2)   |
                                    +--------+---------+
                                             |
              +------------------------------+------------------------------+
              |                              |                              |
     +--------v--------+            +--------v--------+            +--------v--------+
     | Lambda Routes   |            | Lambda Routes   |            | HTTP Proxy      |
     | (from SSM)      |            | (from SSM)      |            | (legacy)        |
     +--------+--------+            +--------+--------+            +--------+--------+
              |                              |                              |
     +--------v--------+            +--------v--------+            +--------v--------+
     | Organization    |            | Search          |            | Content API     |
     | Service Lambdas |            | Service Lambdas |            | (external)      |
     +-----------------+            +-----------------+            +-----------------+
```

## Quick Start

```hcl
module "proxy_gateway" {
  source  = "CarouselGG/proxy-gateway-module/aws"
  version = "1.0.0"

  api_name           = "my-proxy-api"
  stage_name         = "dev"
  aws_region         = "us-west-2"
  custom_domain_name = "api.dev.example.com"
  hosted_zone_id     = "Z1234567890ABC"

  # Read Lambda routes from SSM parameters published by backend services
  lambda_route_ssm_parameters = [
    "/myapp/organization/dev/lambda-routes",
    "/myapp/search/dev/lambda-routes"
  ]

  # HTTP proxy for non-migrated services
  http_proxy_routes = {
    content = {
      path_prefix = "content"
      target_url  = "https://content.api.dev.example.com/{proxy}"
    }
  }
}
```

## Backend Service Configuration

Each backend service publishes its routes to SSM and grants API Gateway permission to invoke its Lambdas:

```hcl
# In backend service Terraform (e.g., organization service)

locals {
  routes = {
    "GET /organization/list"              = aws_lambda_function.list_orgs
    "GET /organization/{id}"              = aws_lambda_function.get_org
    "POST /organization"                  = aws_lambda_function.create_org
    "PUT /organization/{id}"              = aws_lambda_function.update_org
    "DELETE /organization/{id}"           = aws_lambda_function.delete_org
  }
}

# Export routes to SSM for proxy gateway discovery
resource "aws_ssm_parameter" "lambda_routes" {
  name = "/myapp/organization/${terraform.workspace}/lambda-routes"
  type = "String"
  value = jsonencode({
    for route_key, lambda in local.routes : route_key => lambda.arn
  })
}

# Grant API Gateway permission to invoke Lambdas
resource "aws_lambda_permission" "api_gateway_invoke" {
  for_each = local.routes

  statement_id  = "AllowAPIGatewayInvoke-${md5(each.key)}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
}
```

## Usage Examples

### With VPC Creation

```hcl
module "proxy_gateway" {
  source = "CarouselGG/proxy-gateway-module/aws"

  api_name           = "my-proxy-api"
  stage_name         = "prod"
  aws_region         = "us-west-2"
  custom_domain_name = "api.example.com"
  hosted_zone_id     = "Z1234567890ABC"

  # Create a VPC with public/private subnets
  create_vpc           = true
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = false  # One NAT per AZ for HA

  lambda_route_ssm_parameters = [
    "/myapp/organization/prod/lambda-routes",
    "/myapp/search/prod/lambda-routes"
  ]
}
```

### With CORS Configuration

```hcl
module "proxy_gateway" {
  source = "CarouselGG/proxy-gateway-module/aws"

  api_name           = "my-proxy-api"
  stage_name         = "dev"
  aws_region         = "us-west-2"
  custom_domain_name = "api.dev.example.com"
  hosted_zone_id     = "Z1234567890ABC"

  lambda_route_ssm_parameters = [
    "/myapp/organization/dev/lambda-routes"
  ]

  cors_configuration = {
    allow_origins     = ["https://app.example.com"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers     = ["Content-Type", "Authorization"]
    allow_credentials = true
    max_age           = 3600
  }
}
```

### Mixed Lambda and HTTP Proxy Routes

```hcl
module "proxy_gateway" {
  source = "CarouselGG/proxy-gateway-module/aws"

  api_name           = "my-proxy-api"
  stage_name         = "dev"
  aws_region         = "us-west-2"
  custom_domain_name = "api.dev.example.com"
  hosted_zone_id     = "Z1234567890ABC"

  # Migrated services (direct Lambda invocation)
  lambda_route_ssm_parameters = [
    "/myapp/organization/dev/lambda-routes",
    "/myapp/search/dev/lambda-routes"
  ]

  # Non-migrated services (HTTP proxy)
  http_proxy_routes = {
    content = {
      path_prefix = "content"
      target_url  = "https://content.api.dev.example.com/{proxy}"
    }
    members = {
      path_prefix = "members"
      target_url  = "https://members.api.dev.example.com/{proxy}"
    }
    rules = {
      path_prefix = "rules"
      target_url  = "https://rules.api.dev.example.com/{proxy}"
    }
  }
}
```

## Input Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `api_name` | Name of the Proxy Gateway API | `string` |
| `stage_name` | Name of the API stage (dev, staging, prod) | `string` |
| `aws_region` | AWS region for CloudWatch metrics | `string` |
| `custom_domain_name` | Custom domain name (e.g., api.example.com) | `string` |
| `hosted_zone_id` | Route 53 Hosted Zone ID | `string` |

### Route Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `lambda_route_ssm_parameters` | SSM parameter paths containing Lambda routes | `list(string)` | `[]` |
| `http_proxy_routes` | HTTP proxy routes for non-migrated services | `map(object)` | `{}` |

### VPC Configuration (Optional)

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `create_vpc` | Create a new VPC | `bool` | `false` |
| `vpc_cidr` | VPC CIDR block | `string` | `"10.0.0.0/16"` |
| `availability_zones` | List of AZs to use | `list(string)` | Auto-detected |
| `public_subnet_cidrs` | Public subnet CIDRs | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `private_subnet_cidrs` | Private subnet CIDRs | `list(string)` | `["10.0.10.0/24", "10.0.11.0/24"]` |
| `enable_nat_gateway` | Create NAT gateways | `bool` | `false` |
| `single_nat_gateway` | Use single NAT gateway | `bool` | `true` |

### API Gateway Settings

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `api_description` | API Gateway description | `string` | `null` |
| `throttling_burst_limit` | Burst limit (0-5000) | `number` | `500` |
| `throttling_rate_limit` | Rate limit (0-10000) | `number` | `1000` |
| `log_retention_days` | CloudWatch log retention | `number` | `14` |
| `cors_configuration` | CORS settings | `object` | `null` |

## Outputs

| Name | Description |
|------|-------------|
| `api_id` | API Gateway ID |
| `api_endpoint` | Default endpoint URL |
| `api_execution_arn` | Execution ARN for Lambda permissions |
| `custom_domain_name` | Custom domain name |
| `vpc_id` | VPC ID (if created) |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `lambda_route_count` | Number of Lambda routes |
| `log_group_arn` | CloudWatch log group ARN |

## Why Direct Lambda Invocation?

This module uses `AWS_PROXY` integration to invoke Lambdas directly instead of routing through an ALB or VPC Link:

**Benefits:**
- **Lower Latency** - No ALB hop required
- **Lower Cost** - No ALB ($16/month) or NAT Gateway fees
- **Simpler Architecture** - No VPC Link or security group management
- **Independent Scaling** - Each Lambda scales with its own concurrency limits
- **Separate Logs** - Each Lambda has its own CloudWatch log group
- **Resource Tuning** - Individual memory/timeout per function

**Trade-offs:**
- Requires Lambda permissions for API Gateway
- Route definitions in Terraform instead of Lambda code

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.0 |
| AWS Provider | >= 4.0 |

## License

MIT License - see [LICENSE](LICENSE) file for details.
