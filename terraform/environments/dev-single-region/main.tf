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
  region = var.primary_region
}

locals {
  project_name = "url-shortener"
  environment  = "dev"
  
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# DynamoDB Table
module "dynamodb" {
  source = "../../modules/dynamodb"
  
  table_name     = "${local.project_name}-${local.environment}"
  environment    = local.environment
  enable_streams = false
  tags           = local.common_tags
}

# Lambda Functions
module "create_lambda" {
  source = "../../modules/lambda"
  
  function_name      = "${local.project_name}-create-${local.environment}"
  source_dir         = "${path.module}/../../../src/lambda/create-url"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb.table_name
    BASE_URL   = "https://example.com" # Will be updated after API Gateway creation
    AWS_REGION = var.primary_region
  }
  
  tags = local.common_tags
}

module "redirect_lambda" {
  source = "../../modules/lambda"
  
  function_name      = "${local.project_name}-redirect-${local.environment}"
  source_dir         = "${path.module}/../../../src/lambda/redirect"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb.table_name
    AWS_REGION = var.primary_region
  }
  
  tags = local.common_tags
}

module "health_lambda" {
  source = "../../modules/lambda"
  
  function_name      = "${local.project_name}-health-${local.environment}"
  source_dir         = "${path.module}/../../../src/lambda/health-check"
  handler            = "index.handler"
  runtime            = "nodejs18.x"
  timeout            = 10
  memory_size        = 128
  dynamodb_table_arn = module.dynamodb.table_arn
  
  environment_variables = {
    TABLE_NAME = module.dynamodb.table_name
    AWS_REGION = var.primary_region
  }
  
  tags = local.common_tags
}

# API Gateway
module "api_gateway" {
  source = "../../modules/api-gateway"
  
  api_name                   = "${local.project_name}-api-${local.environment}"
  create_lambda_name         = module.create_lambda.function_name
  create_lambda_invoke_arn   = module.create_lambda.invoke_arn
  redirect_lambda_name       = module.redirect_lambda.function_name
  redirect_lambda_invoke_arn = module.redirect_lambda.invoke_arn
  health_lambda_name         = module.health_lambda.function_name
  health_lambda_invoke_arn   = module.health_lambda.invoke_arn
  
  tags = local.common_tags
}