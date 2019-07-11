terraform {
  required_version = ">= 0.12"
}

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region  = var.aws_region
  version = "~> 2.2"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

locals {
  s3_bucket_arn_pattern = "arn:aws:s3:::exim-dappbot-*"
  default_tags = {
    Application = "DappBot"
    ManagedBy   = "Terraform"
  }
  created_dns_root   = ".${var.root_domain}"
  api_domain         = "${var.subdomain}.${var.root_domain}"
  wildcard_cert_arn  = var.create_wildcard_cert ? aws_acm_certificate.cloudfront_cert[0].arn : data.aws_acm_certificate.cloudfront_cert[0].arn
  provision_api_cert = var.existing_cert_domain == ""

  alternate_api_cert_aliases = [local.dapphub_dns, local.dappbot_manager_dns]
  all_api_cert_aliases       = concat([local.api_domain], local.alternate_api_cert_aliases)
  api_cert_arn = element(
    coalescelist(
      data.aws_acm_certificate.api_cert.*.arn,
      aws_acm_certificate.api_cert.*.arn,
      [""],
    ),
    0,
  )

  dapphub_dns         = "${var.dapphub_subdomain}.${var.root_domain}"
  dappbot_manager_dns = "${var.dappbot_manager_subdomain}.${var.root_domain}"

  image_url              = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.codebuild_image}"
  api_gateway_source_arn = "${aws_api_gateway_rest_api.dapp_api.execution_arn}/*/*/*"

  base_lambda_uri    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions"
  dappbot_lambda_uri = "${local.base_lambda_uri}/${aws_lambda_function.dappbot_api_lambda.arn}/invocations"
  dapphub_lambda_uri = "${local.base_lambda_uri}/${aws_lambda_function.dapphub_view_lambda.arn}/invocations"
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {
}

data "aws_route53_zone" "hosted_zone" {
  name = "${var.root_domain}."
}

# ---------------------------------------------------------------------------------------------------------------------
# SHARED S3 BUCKETS & KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "dappbot-artifacts-${var.subdomain}"
  acl           = "private"
  force_destroy = true

  tags = local.default_tags
}

resource "aws_s3_bucket" "dappseed_bucket" {
  bucket        = "dappbot-dappseeds-${var.subdomain}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = local.default_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT API LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

# Wait ensures that the role is fully created when Lambda tries to assume it.
resource "null_resource" "dappbot_private_api_wait" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [aws_iam_role.dappbot_private_api_iam]
}

resource "aws_lambda_function" "dappbot_api_lambda" {
  filename         = "dappbot-api-lambda.zip"
  function_name    = "dappbot-api-lambda-${var.subdomain}"
  role             = aws_iam_role.dappbot_private_api_iam.arn
  handler          = "index.privateHandler"
  source_code_hash = filebase64sha256("dappbot-api-lambda.zip")
  runtime          = "nodejs8.10"
  timeout          = 10

  environment {
    variables = {
      COGNITO_USER_POOL = aws_cognito_user_pool.registered_users.id
      DDB_TABLE         = aws_dynamodb_table.dapp_table.id
      DNS_ROOT          = local.created_dns_root
      SQS_QUEUE         = aws_sqs_queue.dappbot.id
    }
  }

  depends_on = [null_resource.dappbot_private_api_wait]

  tags = local.default_tags
}

resource "aws_lambda_permission" "api_gateway_invoke_dappbot_api_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPHUB VIEW LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

# Wait ensures that the role is fully created when Lambda tries to assume it.
resource "null_resource" "dappbot_public_api_wait" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [aws_iam_role.dappbot_public_api_iam]
}

resource "aws_lambda_function" "dapphub_view_lambda" {
  filename         = "dappbot-api-lambda.zip"
  function_name    = "dapphub-view-lambda-${var.subdomain}"
  role             = aws_iam_role.dappbot_public_api_iam.arn
  handler          = "index.publicHandler"
  source_code_hash = filebase64sha256("dappbot-api-lambda.zip")
  runtime          = "nodejs8.10"
  timeout          = 5

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.dapp_table.id
    }
  }

  depends_on = [null_resource.dappbot_public_api_wait]

  tags = local.default_tags
}

resource "aws_lambda_permission" "api_gateway_invoke_dapphub_view_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dapphub_view_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT MANAGER LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

# Wait ensures that the role is fully created when Lambda tries to assume it.
resource "null_resource" "dappbot_manager_wait" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [aws_iam_role.dappbot_manager_iam]
}

resource "aws_lambda_function" "dappbot_manager_lambda" {
  filename      = "dappbot-manager-lambda.zip"
  function_name = "dappbot-manager-${var.subdomain}"

  role             = aws_iam_role.dappbot_manager_iam.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("dappbot-manager-lambda.zip")
  runtime          = "nodejs8.10"
  timeout          = 60

  environment {
    variables = {
      DDB_TABLE                = aws_dynamodb_table.dapp_table.id
      R53_HOSTED_ZONE_ID       = data.aws_route53_zone.hosted_zone.zone_id
      DNS_ROOT                 = local.created_dns_root
      CODEBUILD_ID             = aws_codebuild_project.dappbot_builder.id
      CODEBUILD_GENERATE_ID    = aws_codebuild_project.dappbot_enterprise_generator.id
      CODEBUILD_BUILD_ID       = aws_codebuild_project.dappbot_enterprise_builder.id
      PIPELINE_ROLE_ARN        = aws_iam_role.dappbot_codepipeline_iam.arn
      ARTIFACT_BUCKET          = aws_s3_bucket.artifact_bucket.id
      DAPPSEED_BUCKET          = aws_s3_bucket.dappseed_bucket.id
      WILDCARD_CERT_ARN        = local.wildcard_cert_arn
      COGNITO_USER_POOL        = aws_cognito_user_pool.registered_users.id
      SENDGRID_API_KEY         = var.sendgrid_key
      SERVICES_LAMBDA_FUNCTION = aws_lambda_function.dappbot_event_listener_lambda.function_name
      GITHUB_TOKEN             = var.service_github_token
    }
  }

  depends_on = [null_resource.dappbot_manager_wait]

  tags = local.default_tags
}

resource "aws_lambda_permission" "sqs_invoke_lambda" {
  statement_id  = "SqsAllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_manager_lambda.function_name
  principal     = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.dappbot.arn
}

resource "aws_lambda_event_source_mapping" "dappbot_sqs_event" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.dappbot.arn
  enabled          = true
  function_name    = aws_lambda_function.dappbot_manager_lambda.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT MANAGER DEAD LETTER FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
# Wait ensures that the role is fully created when Lambda tries to assume it.
resource "null_resource" "dappbot_deadletter_wait" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [aws_iam_role.dappbot_deadletter_iam]
}

resource "aws_lambda_function" "dappbot_manager_deadletter_lambda" {
  filename         = "dappbot-manager-lambda.zip"
  function_name    = "dappbot-manager-deadletter-${var.subdomain}"
  role             = aws_iam_role.dappbot_deadletter_iam.arn
  handler          = "index.deadLetterHandler"
  source_code_hash = filebase64sha256("dappbot-manager-lambda.zip")
  runtime          = "nodejs8.10"
  timeout          = 30

  environment {
    variables = {
      DDB_TABLE                = aws_dynamodb_table.dapp_table.id
      R53_HOSTED_ZONE_ID       = data.aws_route53_zone.hosted_zone.zone_id
      DNS_ROOT                 = local.created_dns_root
      CODEBUILD_ID             = aws_codebuild_project.dappbot_builder.id
      CODEBUILD_GENERATE_ID    = aws_codebuild_project.dappbot_enterprise_generator.id
      CODEBUILD_BUILD_ID       = aws_codebuild_project.dappbot_enterprise_builder.id
      PIPELINE_ROLE_ARN        = aws_iam_role.dappbot_codepipeline_iam.arn
      ARTIFACT_BUCKET          = aws_s3_bucket.artifact_bucket.id
      DAPPSEED_BUCKET          = aws_s3_bucket.dappseed_bucket.id
      WILDCARD_CERT_ARN        = local.wildcard_cert_arn
      COGNITO_USER_POOL        = aws_cognito_user_pool.registered_users.id
      SENDGRID_API_KEY         = var.sendgrid_key
      SERVICES_LAMBDA_FUNCTION = aws_lambda_function.dappbot_event_listener_lambda.function_name
      GITHUB_TOKEN             = var.service_github_token
    }
  }

  depends_on = [null_resource.dappbot_manager_wait]

  tags = local.default_tags
}

resource "aws_lambda_permission" "sqs_invoke_deadletter_lambda" {
  statement_id  = "SqsAllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_manager_deadletter_lambda.function_name
  principal     = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.dappbot.arn
}

resource "aws_lambda_event_source_mapping" "dappbot_deadletter_sqs_event" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.dappbot_deadletter.arn
  enabled          = true
  function_name    = aws_lambda_function.dappbot_manager_deadletter_lambda.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT EVENT LISTENER LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
# Wait ensures that the role is fully created when Lambda tries to assume it.
resource "null_resource" "dappbot_event_listener_wait" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = [aws_iam_role.dappbot_event_listener_iam]
}

resource "aws_lambda_function" "dappbot_event_listener_lambda" {
  filename         = "dappbot-event-listener-lambda.zip"
  function_name    = "dappbot-event-listener-lambda-${var.subdomain}"
  role             = aws_iam_role.dappbot_event_listener_iam.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("dappbot-event-listener-lambda.zip")
  runtime          = "nodejs8.10"
  timeout          = 900
  memory_size      = 256

  environment {
    variables = {
      DAPP_TABLE         = aws_dynamodb_table.dapp_table.id
      LAPSED_USERS_TABLE = aws_dynamodb_table.lapsed_users_table.id
      R53_HOSTED_ZONE_ID = data.aws_route53_zone.hosted_zone.zone_id
      DNS_ROOT           = local.created_dns_root
      CODEBUILD_ID       = aws_codebuild_project.dappbot_builder.id
      PIPELINE_ROLE_ARN  = aws_iam_role.dappbot_codepipeline_iam.arn
      ARTIFACT_BUCKET    = aws_s3_bucket.artifact_bucket.id
      DAPPSEED_BUCKET    = aws_s3_bucket.dappseed_bucket.id
      WILDCARD_CERT_ARN  = local.wildcard_cert_arn
      COGNITO_USER_POOL  = aws_cognito_user_pool.registered_users.id
      SENDGRID_API_KEY   = var.sendgrid_key
      GITHUB_TOKEN       = var.service_github_token
    }
  }

  depends_on = [null_resource.dappbot_event_listener_wait]

  tags = local.default_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# TODO: Add S3 bucket for Lambda fxn (env var) to support full CD
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# CODEBUILD PROJECT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_codebuild_project" "dappbot_builder" {
  name          = "dappbot-builder-${var.subdomain}"
  build_timeout = 10
  service_role  = aws_iam_role.dappbot_codepipeline_iam.arn

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = local.image_url
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      name  = "NPM_USER"
      value = var.npm_user
    }

    environment_variable {
      name  = "NPM_PASS"
      value = var.npm_pass
    }

    environment_variable {
      name  = "NPM_EMAIL"
      value = var.npm_email
    }
  }

  artifacts {
    type                = "CODEPIPELINE"
    encryption_disabled = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.local_file.buildspec.content
  }

  tags = local.default_tags
}

data "local_file" "buildspec" {
  filename = "${path.module}/codebuild-specs/buildspec.yml"
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEBUILD PROJECT ENTERPRISE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_codebuild_project" "dappbot_enterprise_generator" {
  name          = "dappbot-enterprise-generator-${var.subdomain}"
  build_timeout = 10
  service_role  = aws_iam_role.dappbot_codepipeline_iam.arn

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = local.image_url
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      name  = "NPM_USER"
      value = var.npm_user
    }

    environment_variable {
      name  = "NPM_PASS"
      value = var.npm_pass
    }

    environment_variable {
      name  = "NPM_EMAIL"
      value = var.npm_email
    }
  }

  artifacts {
    type                = "CODEPIPELINE"
    encryption_disabled = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.local_file.buildspec_enterprise_generate.content
  }

  tags = local.default_tags
}

data "local_file" "buildspec_enterprise_generate" {
  filename = "${path.module}/codebuild-specs/buildspec-enterprise-generate.yml"
}

resource "aws_codebuild_project" "dappbot_enterprise_builder" {
  name          = "dappbot-enterprise-builder-${var.subdomain}"
  build_timeout = 10
  service_role  = aws_iam_role.dappbot_codepipeline_iam.arn

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = local.image_url
    image_pull_credentials_type = "SERVICE_ROLE"
  }

  artifacts {
    type                = "CODEPIPELINE"
    encryption_disabled = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = data.local_file.buildspec_enterprise_build.content
  }

  tags = local.default_tags
}

data "local_file" "buildspec_enterprise_build" {
  filename = "${path.module}/codebuild-specs/buildspec-enterprise-build.yml"
}

# ---------------------------------------------------------------------------------------------------------------------
# ACM CERT for CLOUDFRONT
# ---------------------------------------------------------------------------------------------------------------------
data "aws_acm_certificate" "cloudfront_cert" {
  count = var.create_wildcard_cert ? 0 : 1

  domain = "*${local.created_dns_root}"
}

resource "aws_acm_certificate" "cloudfront_cert" {
  count = var.create_wildcard_cert ? 1 : 0

  domain_name       = "*${local.created_dns_root}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cloudfront_wildcard" {
  count = var.create_wildcard_cert ? 1 : 0

  name    = aws_acm_certificate.cloudfront_cert[0].domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.cloudfront_cert[0].domain_validation_options[0].resource_record_type
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  records = [aws_acm_certificate.cloudfront_cert[0].domain_validation_options[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cloudfront_validation" {
  count = var.create_wildcard_cert ? 1 : 0

  certificate_arn         = aws_acm_certificate.cloudfront_cert[0].arn
  validation_record_fqdns = [aws_route53_record.cloudfront_wildcard[0].fqdn]
}

# ---------------------------------------------------------------------------------------------------------------------
# ACM CERT for API
# ---------------------------------------------------------------------------------------------------------------------
data "aws_acm_certificate" "api_cert" {
  count = local.provision_api_cert ? 0 : 1

  domain      = var.existing_cert_domain
  most_recent = true
}

resource "aws_acm_certificate" "api_cert" {
  count = local.provision_api_cert ? 1 : 0

  domain_name               = local.api_domain
  subject_alternative_names = local.alternate_api_cert_aliases
  validation_method         = "DNS"
}

resource "aws_acm_certificate_validation" "api_cert" {
  count = local.provision_api_cert ? 1 : 0

  certificate_arn         = element(coalescelist(aws_acm_certificate.api_cert.*.arn, [""]), 0)
  validation_record_fqdns = aws_route53_record.api_cert_validation.*.fqdn

  provisioner "local-exec" {
    command = "sleep 20"
  }
}

resource "aws_route53_record" "api_cert_validation" {
  count = local.provision_api_cert ? length(local.all_api_cert_aliases) : 0

  name    = aws_acm_certificate.api_cert.0.domain_validation_options[count.index]["resource_record_name"]
  type    = aws_acm_certificate.api_cert.0.domain_validation_options[count.index]["resource_record_type"]
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  records = [aws_acm_certificate.api_cert.0.domain_validation_options[count.index]["resource_record_value"]]
  ttl     = 60
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "dapp_api" {
  name        = "dappbot-${var.subdomain}"
  description = "Proxy to handle requests to the Dappbot & Dapphub API"
}

resource "aws_api_gateway_deployment" "dapp_api_deploy_v1" {
  depends_on = [
    aws_api_gateway_integration.dapphub_integration,
    aws_api_gateway_integration.dappbot_integration,
    aws_api_gateway_integration.dappbot_private_list_integration,
    aws_api_gateway_method.dapphub_method,
    aws_api_gateway_method.dappbot_method,
    aws_api_gateway_method.dappbot_private_list_method,
  ]

  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  stage_name  = "v1"
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY PRIVATE: DAPPBOT API
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_api_gateway_resource" "dappbot_private_resource" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_rest_api.dapp_api.root_resource_id
  path_part   = "private"
}

resource "aws_api_gateway_resource" "dappbot_private_proxy_resource" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_resource.dappbot_private_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "dappbot_method" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy_resource.id
  http_method = "ANY"

  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_auth.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "dappbot_integration" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy_resource.id
  http_method = aws_api_gateway_method.dappbot_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dappbot_lambda_uri

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_method" "dappbot_private_list_method" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_resource.id
  http_method = "GET"

  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_auth.id
}

resource "aws_api_gateway_integration" "dappbot_private_list_integration" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_resource.id
  http_method = aws_api_gateway_method.dappbot_private_list_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dappbot_lambda_uri
}

resource "aws_api_gateway_authorizer" "api_auth" {
  name          = "dappbot-auth-${var.subdomain}"
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  provider_arns = [aws_cognito_user_pool.registered_users.arn]

  identity_source = "method.request.header.Authorization"
  type            = "COGNITO_USER_POOLS"
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY PUBLIC: DAPPHUB VIEW
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "dapphub_public_resource" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_rest_api.dapp_api.root_resource_id
  path_part   = "public"
}

resource "aws_api_gateway_resource" "dapphub_public_proxy_resource" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_resource.dapphub_public_resource.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "dapphub_method" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dapphub_public_proxy_resource.id
  http_method = "ANY"

  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dapphub_integration" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dapphub_public_proxy_resource.id
  http_method = aws_api_gateway_method.dapphub_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dapphub_lambda_uri
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY RESPONSES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "ACCESS_DENIED"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "api_configuration_error" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "API_CONFIGURATION_ERROR"
  status_code   = "500"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "authorizer_configuration_error" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "AUTHORIZER_CONFIGURATION_ERROR"
  status_code   = "500"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "authorizer_failure" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "AUTHORIZER_FAILURE"
  status_code   = "500"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "bad_request_parameters" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "BAD_REQUEST_PARAMETERS"
  status_code   = "400"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "bad_request_body" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "BAD_REQUEST_BODY"
  status_code   = "400"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "expired_token" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "EXPIRED_TOKEN"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "integration_failure" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INTEGRATION_FAILURE"
  status_code   = "504"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "integration_timeout" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INTEGRATION_TIMEOUT"
  status_code   = "504"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "invalid_api_key" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INVALID_API_KEY"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "invalid_signature" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INVALID_SIGNATURE"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "missing_authentication_token" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "MISSING_AUTHENTICATION_TOKEN"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "quota_exceeded" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "QUOTA_EXCEEDED"
  status_code   = "429"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "request_too_large" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "REQUEST_TOO_LARGE"
  status_code   = "413"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "resource_not_found" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "RESOURCE_NOT_FOUND"
  status_code   = "404"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "throttled" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "THROTTLED"
  status_code   = "429"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "UNAUTHORIZED"
  status_code   = "401"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "unsupported_media_type" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "UNSUPPORTED_MEDIA_TYPE"
  status_code   = "415"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "waf_filtered" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "WAF_FILTERED"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CUSTOM DNS NAME
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_domain_name" "domain" {
  certificate_arn = local.api_cert_arn
  domain_name     = local.api_domain

  depends_on = [aws_acm_certificate_validation.api_cert]
}

resource "aws_api_gateway_base_path_mapping" "base_path_mapping" {
  api_id = aws_api_gateway_rest_api.dapp_api.id

  domain_name = aws_api_gateway_domain_name.domain.domain_name
}

resource "aws_route53_record" "example" {
  name    = aws_api_gateway_domain_name.domain.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.domain.cloudfront_zone_id
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMODB TABLES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_dynamodb_table" "dapp_table" {
  name         = "dappbot-dapps-${var.subdomain}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "DappName"

  global_secondary_index {
    name     = "OwnerEmailIndex"
    hash_key = "OwnerEmail"

    projection_type = "ALL"
  }

  attribute {
    name = "DappName"
    type = "S"
  }

  attribute {
    name = "OwnerEmail"
    type = "S"
  }

  tags = local.default_tags
}

resource "aws_dynamodb_table" "lapsed_users_table" {
  name         = "dappbot-lapsed-users-${var.subdomain}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserEmail"

  attribute {
    name = "UserEmail"
    type = "S"
  }

  tags = local.default_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# COGNITO RESOURCES FOR AUTH
# ---------------------------------------------------------------------------------------------------------------------
locals {
  redirect_uri = "https://www.eximchain.com"
}

resource "aws_cognito_user_pool" "registered_users" {
  name = "dappbot-users-${var.subdomain}"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
    unused_account_validity_days = 7
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_uppercase = false
    require_numbers   = false
    require_symbols   = false
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_LINK"
  }

  // Legacy Proof of Concept
  schema {
    name = "num_dapps"

    attribute_data_type      = "Number"
    developer_only_attribute = false
    mutable                  = true

    # Custom attributes cannot be required
    required = false

    number_attribute_constraints {
      min_value = 0
      max_value = 1000
    }
  }

  schema {
    name = "standard_limit"

    attribute_data_type      = "Number"
    developer_only_attribute = false
    mutable                  = true

    # Custom attributes cannot be required
    required = false

    number_attribute_constraints {
      min_value = 0
      max_value = 1000
    }
  }

  schema {
    name = "professional_limit"

    attribute_data_type      = "Number"
    developer_only_attribute = false
    mutable                  = true

    # Custom attributes cannot be required
    required = false

    number_attribute_constraints {
      min_value = 0
      max_value = 1000
    }
  }

  schema {
    name = "enterprise_limit"

    attribute_data_type      = "Number"
    developer_only_attribute = false
    mutable                  = true

    # Custom attributes cannot be required
    required = false

    number_attribute_constraints {
      min_value = 0
      max_value = 1000
    }
  }

  schema {
    name = "payment_provider"

    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true

    # Custom attributes cannot be required
    required = false

    string_attribute_constraints {
      min_length = 0
      max_length = 32
    }
  }

  schema {
    name = "payment_status"

    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true

    # Custom attributes cannot be required
    required = false

    string_attribute_constraints {
      min_length = 0
      max_length = 32
    }
  }

  tags = local.default_tags
}

resource "aws_cognito_user_pool_domain" "cognito_domain" {
  domain       = "dappbot-${var.subdomain}"
  user_pool_id = aws_cognito_user_pool.registered_users.id
}

resource "aws_cognito_user_pool_client" "api_client" {
  name         = "dappbot-client-${var.subdomain}"
  user_pool_id = aws_cognito_user_pool.registered_users.id

  allowed_oauth_flows  = ["code", "implicit"]
  allowed_oauth_scopes = ["email", "openid", "profile"]

  allowed_oauth_flows_user_pool_client = true

  callback_urls = [local.redirect_uri]
  logout_urls          = [local.redirect_uri]
  default_redirect_uri = local.redirect_uri

  supported_identity_providers = ["COGNITO"]

  read_attributes  = ["email", "custom:num_dapps", "custom:standard_limit", "custom:professional_limit", "custom:enterprise_limit"]
  write_attributes = ["email"]

  # Allows us to skip the challenge flow for script-based testing
  explicit_auth_flows = ["USER_PASSWORD_AUTH"]
}

# ---------------------------------------------------------------------------------------------------------------------
# SQS QUEUE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_sqs_queue" "dappbot" {
  name                       = "dappbot-queue-${var.subdomain}"
  message_retention_seconds  = 3600
  visibility_timeout_seconds = 60

  redrive_policy = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.dappbot_deadletter.arn}\",\"maxReceiveCount\":3}"

  tags = local.default_tags
}

resource "aws_sqs_queue" "dappbot_deadletter" {
  name                       = "dappbot-deadletter-${var.subdomain}"
  message_retention_seconds  = 1209600
  visibility_timeout_seconds = 30

  tags = local.default_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPHUB WEBSITE
# ---------------------------------------------------------------------------------------------------------------------
module "dapphub_website" {
  source = "git@github.com:Eximchain/terraform-aws-static-website.git"

  dns_name    = local.dapphub_dns
  domain_root = var.root_domain

  website_bucket_name = "dapphub-website-${var.subdomain}"
  log_bucket_name     = "dapphub-website-logs-${var.subdomain}"

  acm_cert_arn = local.api_cert_arn

  github_website_repo   = "dapphub-spa"
  github_website_branch = var.dapphub_branch
  deployment_directory  = "build"
  build_command         = "npm install && npm run build"

  force_destroy_buckets = true

  env = {
    REACT_APP_DAPPBOT_URL = "https://${local.api_domain}"
    REACT_APP_WEB3_URL    = "https://gamma-tx-executor-us-east.eximchain-dev.com"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT MANAGER WEBSITE
# ---------------------------------------------------------------------------------------------------------------------
module "dappbot_manager" {
  source = "git@github.com:Eximchain/terraform-aws-static-website.git"

  dns_name    = local.dappbot_manager_dns
  domain_root = var.root_domain

  website_bucket_name = "dappbot-manager-${var.subdomain}"
  log_bucket_name     = "dappbot-manager-logs-${var.subdomain}"

  acm_cert_arn = local.api_cert_arn

  github_website_repo   = "dappbot-management-spa"
  github_website_branch = var.dappbot_manager_branch
  deployment_directory  = "build"
  build_command         = "npm install && npm run build"

  force_destroy_buckets = true

  env = {
    REACT_APP_DAPPSMITH_ENDPOINT         = "https://${local.api_domain}"
    REACT_APP_AWS_REGION                 = var.aws_region
    REACT_APP_USER_POOL_ID               = aws_cognito_user_pool.registered_users.id
    REACT_APP_STRIPE_PUBLISHABLE_API_KEY = "TODO: Fill in"
    REACT_APP_USER_POOL_CLIENT_ID        = aws_cognito_user_pool_client.api_client.id
    REACT_APP_PAYMENT_ENDPOINT           = "TODO: Deploy & fill in "
    REACT_APP_MAILCHIMP_URL              = "https://eximchain.us20.list-manage.com/subscribe/post?u=bcabb5ebaaec9e5f833f9d760&id=0bdb65877c"
    REACT_APP_MAILCHIMP_AUDENCE_ID       = "b_bcabb5ebaaec9e5f833f9d760_0bdb65877c"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PERIODIC CLEANUP
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_sns_topic" "cleanup_event" {
  name = "dappbot-cleanup-${var.subdomain}"
}

resource "aws_cloudwatch_event_rule" "cleanup_timer" {
  name                = "dappbot-cleanup-${var.subdomain}"
  schedule_expression = var.cleanup_interval
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.cleanup_timer.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.cleanup_event.arn

  input = "{\"event\":\"CLEANUP\"}"
}

resource "aws_sns_topic_subscription" "cleanup_lambda" {
  topic_arn = aws_sns_topic.cleanup_event.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.dappbot_event_listener_lambda.arn
}

resource "aws_lambda_permission" "sns_invoke_cleanup_lambda" {
  statement_id  = "CleanupAllowExecutionFromSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_event_listener_lambda.function_name
  principal     = "sns.amazonaws.com"

  source_arn = aws_sns_topic.cleanup_event.arn
}

resource "aws_sns_topic_policy" "cleanup" {
  arn    = aws_sns_topic.cleanup_event.arn
  policy = data.aws_iam_policy_document.cleanup_topic_policy.json
}

data "aws_iam_policy_document" "cleanup_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.cleanup_event.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PAYMENT EVENTS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_sns_topic" "payment_events" {
  name = "dappbot-payment-events-${var.subdomain}"
}

resource "aws_sns_topic_subscription" "payment_events_lambda" {
  topic_arn = aws_sns_topic.payment_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.dappbot_event_listener_lambda.arn
}

resource "aws_lambda_permission" "sns_invoke_payment_events_lambda" {
  statement_id  = "PaymentEventsAllowExecutionFromSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_event_listener_lambda.function_name
  principal     = "sns.amazonaws.com"

  source_arn = aws_sns_topic.payment_events.arn
}

// TODO: Convert these two resources to use for_each syntax when it's available
resource "aws_sns_topic_policy" "payment_events" {
  count = length(var.payment_event_publishers)

  arn    = aws_sns_topic.payment_events.arn
  policy = element(data.aws_iam_policy_document.payment_event_topic_policy.*.json, count.index)
}

data "aws_iam_policy_document" "payment_event_topic_policy" {
  count = length(var.payment_event_publishers)

  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [element(var.payment_event_publishers, count.index)]
  }
}