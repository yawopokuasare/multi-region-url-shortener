terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

locals {
  project_name = "url-shortener"
  environment  = "prod"
  
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# ========================================
# PRIMARY REGION (us-east-1)
# ========================================

module "dynamodb_primary" {
  source = "../../modules/dynamodb"
  
  providers = {
    aws = aws.primary
  }
  
  table_name     = "${local.project_name}-${local.environment}"
  environment    = local.environment
  enable_streams = true
  tags           = merge(local.common_tags, { Region = var.primary_region })
}

module "create_lambda_primary" {
  source = "../../modules/lambda"
  
  providers = {
    aws = aws.primary
  }
  
  function_name      = "${local.project_name}-create-${local.environment}-primary"
  source_dir         = "${path.module}/../../../src/lambda/create-url"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb_primary.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb_primary.table_name
    BASE_URL   = var.domain_name != "" ? "https://${var.domain_name}" : "https://example.com"
  }
  
  tags = merge(local.common_tags, { Region = var.primary_region })
}

module "redirect_lambda_primary" {
  source = "../../modules/lambda"
  
  providers = {
    aws = aws.primary
  }
  
  function_name      = "${local.project_name}-redirect-${local.environment}-primary"
  source_dir         = "${path.module}/../../../src/lambda/redirect"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb_primary.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb_primary.table_name
    
  }
  
  tags = merge(local.common_tags, { Region = var.primary_region })
}

module "health_lambda_primary" {
  source = "../../modules/lambda"
  
  providers = {
    aws = aws.primary
  }
  
  function_name      = "${local.project_name}-health-${local.environment}-primary"
  source_dir         = "${path.module}/../../../src/lambda/health-check"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb_primary.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb_primary.table_name
    
  }
  
  tags = merge(local.common_tags, { Region = var.primary_region })
}

module "api_gateway_primary" {
  source = "../../modules/api-gateway"
  
  providers = {
    aws = aws.primary
  }
  
  api_name                   = "${local.project_name}-api-${local.environment}-primary"
  create_lambda_name         = module.create_lambda_primary.function_name
  create_lambda_invoke_arn   = module.create_lambda_primary.invoke_arn
  redirect_lambda_name       = module.redirect_lambda_primary.function_name
  redirect_lambda_invoke_arn = module.redirect_lambda_primary.invoke_arn
  health_lambda_name         = module.health_lambda_primary.function_name
  health_lambda_invoke_arn   = module.health_lambda_primary.invoke_arn
  
  tags = merge(local.common_tags, { Region = var.primary_region })
}

# ========================================
# SECONDARY REGION (us-west-2)
# ========================================

module "dynamodb_secondary" {
  source = "../../modules/dynamodb"
  
  providers = {
    aws = aws.secondary
  }
  
  table_name     = "${local.project_name}-${local.environment}"
  environment    = local.environment
  enable_streams = true
  tags           = merge(local.common_tags, { Region = var.secondary_region })
}

# Create Global Table
# Add replica to primary table (Global Table V2)
resource "null_resource" "enable_global_table" {
  provisioner "local-exec" {
    command = <<EOF
aws dynamodb update-table \
  --table-name ${module.dynamodb_primary.table_name} \
  --region ${var.primary_region} \
  --replica-updates '[{"Create": {"RegionName": "${var.secondary_region}"}}]' \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES || true
EOF
  }
  
  depends_on = [
    module.dynamodb_primary,
    module.dynamodb_secondary
  ]
} 

module "create_lambda_secondary" {
  source = "../../modules/lambda"
  
  providers = {
    aws = aws.secondary
  }
  
  function_name      = "${local.project_name}-create-${local.environment}-secondary"
  source_dir         = "${path.module}/../../../src/lambda/create-url"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb_secondary.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb_secondary.table_name
    BASE_URL   = var.domain_name != "" ? "https://${var.domain_name}" : "https://example.com"
    
  }
  
  tags = merge(local.common_tags, { Region = var.secondary_region })
}

module "redirect_lambda_secondary" {
  source = "../../modules/lambda"
  
  providers = {
    aws = aws.secondary
  }
  
  function_name      = "${local.project_name}-redirect-${local.environment}-secondary"
  source_dir         = "${path.module}/../../../src/lambda/redirect"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb_secondary.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb_secondary.table_name
    
  }
  
  tags = merge(local.common_tags, { Region = var.secondary_region })
}

module "health_lambda_secondary" {
  source = "../../modules/lambda"
  
  providers = {
    aws = aws.secondary
  }
  
  function_name      = "${local.project_name}-health-${local.environment}-secondary"
  source_dir         = "${path.module}/../../../src/lambda/health-check"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb_secondary.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb_secondary.table_name
    
  }
  
  tags = merge(local.common_tags, { Region = var.secondary_region })
}

module "api_gateway_secondary" {
  source = "../../modules/api-gateway"
  
  providers = {
    aws = aws.secondary
  }
  
  api_name                   = "${local.project_name}-api-${local.environment}-secondary"
  create_lambda_name         = module.create_lambda_secondary.function_name
  create_lambda_invoke_arn   = module.create_lambda_secondary.invoke_arn
  redirect_lambda_name       = module.redirect_lambda_secondary.function_name
  redirect_lambda_invoke_arn = module.redirect_lambda_secondary.invoke_arn
  health_lambda_name         = module.health_lambda_secondary.function_name
  health_lambda_invoke_arn   = module.health_lambda_secondary.invoke_arn
  
  tags = merge(local.common_tags, { Region = var.secondary_region })
}

# ========================================
# ROUTE 53 HEALTH CHECKS & FAILOVER
# ========================================

# Health check for primary region
resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  fqdn              = replace(module.api_gateway_primary.api_endpoint, "https://", "")
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(local.common_tags, { 
    Name   = "${local.project_name}-primary-health"
    Region = var.primary_region
  })
}

# Health check for secondary region
resource "aws_route53_health_check" "secondary" {
  provider          = aws.secondary
  fqdn              = replace(module.api_gateway_secondary.api_endpoint, "https://", "")
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(local.common_tags, { 
    Name   = "${local.project_name}-secondary-health"
    Region = var.secondary_region
  })
}

# Route 53 Hosted Zone (only if domain_name is provided)
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  provider = aws.primary
  
  name = var.domain_name

  tags = local.common_tags
}

# Primary record (active)
resource "aws_route53_record" "primary" {
  count = var.domain_name != "" ? 1 : 0
  provider = aws.primary
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = replace(replace(module.api_gateway_primary.api_endpoint, "https://", ""), "/", "")
    zone_id                = "Z1UJRXOUMOOFQ8" # API Gateway hosted zone ID for us-east-1
    evaluate_target_health = true
  }

  set_identifier = "primary"
  
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id
}

# Secondary record (passive)
resource "aws_route53_record" "secondary" {
  count = var.domain_name != "" ? 1 : 0
  provider = aws.primary
  
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = replace(replace(module.api_gateway_secondary.api_endpoint, "https://", ""), "/", "")
    zone_id                = "Z2OJLYMUO9EFXC" # API Gateway hosted zone ID for us-west-2
    evaluate_target_health = true
  }

  set_identifier = "secondary"
  
  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.secondary.id
}

# ========================================
# CLOUDWATCH ALARMS
# ========================================

resource "aws_cloudwatch_metric_alarm" "primary_health" {
  provider = aws.primary
  
  alarm_name          = "${local.project_name}-primary-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Primary region health check failing"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "secondary_health" {
  provider = aws.secondary
  
  alarm_name          = "${local.project_name}-secondary-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Secondary region health check failing"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.secondary.id
  }

  tags = local.common_tags
}