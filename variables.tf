# =============================================================================
# Required Variables
# =============================================================================

variable "api_name" {
  description = "Name of the Proxy Gateway API"
  type        = string

  validation {
    condition     = length(var.api_name) > 0 && length(var.api_name) <= 128
    error_message = "API name must be between 1 and 128 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.api_name))
    error_message = "API name can only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "stage_name" {
  description = "Name of the API stage (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = length(var.stage_name) > 0 && length(var.stage_name) <= 128
    error_message = "Stage name must be between 1 and 128 characters."
  }
}

variable "custom_domain_name" {
  description = "Custom domain name for the API Gateway (e.g., api.example.com)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID for the custom domain"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.hosted_zone_id))
    error_message = "Hosted zone ID must start with 'Z' followed by alphanumeric characters."
  }
}

variable "aws_region" {
  description = "AWS region for CloudWatch metrics"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-east-1, eu-west-2)."
  }
}

# =============================================================================
# Lambda Routes from SSM (Cross-Service Discovery)
# =============================================================================

variable "lambda_route_ssm_parameters" {
  description = <<-EOT
    List of SSM parameter names containing Lambda route configurations.
    Each parameter should contain a JSON object mapping route keys to Lambda ARNs.
    Example: ["/carousel/organization/dev/lambda-routes", "/carousel/search/dev/lambda-routes"]
  EOT
  type        = list(string)
  default     = []
}

# =============================================================================
# HTTP Proxy Routes (Non-migrated Services)
# =============================================================================

variable "http_proxy_routes" {
  description = <<-EOT
    Map of service names to their HTTP proxy configurations for non-migrated services.
    These routes will use HTTP_PROXY integration to forward requests.
    Example:
    {
      content = {
        path_prefix = "content"
        target_url  = "https://content.api.example.com/{proxy}"
      }
    }
  EOT
  type = map(object({
    path_prefix = string
    target_url  = string
  }))
  default = {}
}

# =============================================================================
# VPC Configuration (Optional)
# =============================================================================

variable "create_vpc" {
  description = "Whether to create a new VPC for the proxy gateway"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (only used if create_vpc is true)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones to use for subnets"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways for private subnets"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs (cost-saving for non-prod)"
  type        = bool
  default     = true
}

# =============================================================================
# API Gateway Settings
# =============================================================================

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = null
}

variable "throttling_burst_limit" {
  description = "Burst limit for API throttling (requests per second)"
  type        = number
  default     = 500

  validation {
    condition     = var.throttling_burst_limit >= 0 && var.throttling_burst_limit <= 5000
    error_message = "Burst limit must be between 0 and 5000."
  }
}

variable "throttling_rate_limit" {
  description = "Rate limit for API throttling (requests per second)"
  type        = number
  default     = 1000

  validation {
    condition     = var.throttling_rate_limit >= 0 && var.throttling_rate_limit <= 10000
    error_message = "Rate limit must be between 0 and 10000."
  }
}

# =============================================================================
# Logging
# =============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention value."
  }
}

# =============================================================================
# CORS Configuration
# =============================================================================

variable "cors_configuration" {
  description = "CORS configuration for the API Gateway. Set to null to disable CORS."
  type = object({
    allow_origins     = list(string)
    allow_methods     = optional(list(string), ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
    allow_headers     = optional(list(string), ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"])
    expose_headers    = optional(list(string), [])
    allow_credentials = optional(bool, false)
    max_age           = optional(number, 300)
  })
  default = null
}

# =============================================================================
# Observability
# =============================================================================

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard for the proxy gateway"
  type        = bool
  default     = false
}

variable "enable_alarms" {
  description = "Enable CloudWatch alarms for the proxy gateway"
  type        = bool
  default     = false
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications (required if enable_alarms is true)"
  type        = string
  default     = null
}

variable "alarm_thresholds" {
  description = "Thresholds for CloudWatch alarms"
  type = object({
    error_rate_percent = optional(number, 5)
    p99_latency_ms     = optional(number, 3000)
  })
  default = {}
}

# =============================================================================
# JWT Authorizer (Auth0/OAuth2.0)
# =============================================================================

variable "enable_jwt_authorizer" {
  description = "Enable JWT authorizer for protected routes"
  type        = bool
  default     = false
}

variable "jwt_issuer" {
  description = "JWT issuer URL (e.g., https://your-tenant.auth0.com/)"
  type        = string
  default     = null

  validation {
    condition     = var.jwt_issuer == null || can(regex("^https://", var.jwt_issuer))
    error_message = "JWT issuer must be a valid HTTPS URL."
  }
}

variable "jwt_audience" {
  description = "List of JWT audiences (API identifiers in Auth0)"
  type        = list(string)
  default     = []
}

variable "public_routes" {
  description = <<-EOT
    List of route keys that should NOT require authorization.
    These routes will be publicly accessible without a JWT token.
    Example: ["GET /health", "GET /public/status"]
  EOT
  type        = list(string)
  default     = []
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
