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
    stage = var.root_domain == "dapp.bot" ? var.subdomain == "api" ? "prod" : "staging" : "dev"

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

    dapphub_dns         = var.dapphub_subdomain == "" ? var.root_domain : "${var.dapphub_subdomain}.${var.root_domain}"
    dappbot_manager_dns = var.dappbot_manager_subdomain == "" ? var.root_domain : "${var.dappbot_manager_subdomain}.${var.root_domain}"

    image_url              = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.codebuild_image}"
    api_gateway_source_arn = "${aws_api_gateway_rest_api.dapp_api.execution_arn}/*/*/*"

    base_lambda_uri                      = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions"
    dappbot_lambda_uri                   = "${local.base_lambda_uri}/${aws_lambda_function.dappbot_api_lambda.arn}/invocations"
    dappbot_auth_lambda_uri              = "${local.base_lambda_uri}/${aws_lambda_function.dappbot_auth_api_lambda.arn}/invocations"
    dappbot_config_lambda_uri            = "${local.base_lambda_uri}/${aws_lambda_function.dappbot_config_api_lambda.arn}/invocations"
    dapphub_lambda_uri                   = "${local.base_lambda_uri}/${aws_lambda_function.dapphub_view_lambda.arn}/invocations"
    stripe_management_gateway_lambda_uri = "${local.base_lambda_uri}/${aws_lambda_function.stripe_management_gateway_lambda.arn}/invocations"
    stripe_webhook_gateway_lambda_uri    = "${local.base_lambda_uri}/${aws_lambda_function.stripe_webhook_gateway_lambda.arn}/invocations"
    stripe_signup_gateway_lambda_uri     = "${local.base_lambda_uri}/${aws_lambda_function.stripe_signup_gateway_lambda.arn}/invocations"
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

  resource "aws_s3_bucket" "lambda_deployment_packages" {
    bucket        = "dappbot-lambda-packages-${var.subdomain}"
    acl           = "private"
    force_destroy = true

    tags = local.default_tags
  }

  resource "aws_s3_bucket_object" "default_function" {
    bucket = aws_s3_bucket.lambda_deployment_packages.bucket
    key    = "default-lambda.zip"
    source = "${path.module}/default-lambda.zip"
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

  module "dappbot_api_lambda_pipeline" {
    source = "git@github.com:Eximchain/terraform-aws-lambda-cd-pipeline.git"

    id = "api-${var.subdomain}"

    github_lambda_repo    = "dappbot-api-lambda"
    github_lambda_branch  = var.dappbot_api_lambda_branch_override != "" ? var.dappbot_api_lambda_branch_override : var.lambda_default_branch
    build_command         = "npm install && npm run build"

    deployment_package_filename    = "dappbot-api-lambda.zip"
    deployment_package_bucket_name = aws_s3_bucket.lambda_deployment_packages.bucket

    deployment_target_lambdas = [
      aws_lambda_function.dappbot_api_lambda.function_name,
      aws_lambda_function.dapphub_view_lambda.function_name,
      aws_lambda_function.dappbot_auth_api_lambda.function_name,
      aws_lambda_function.dappbot_config_api_lambda.function_name
    ]

    aws_region            = var.aws_region
    force_destroy_buckets = true
  }

  resource "aws_lambda_function" "dappbot_api_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dappbot-api-lambda-${var.subdomain}"
    role             = aws_iam_role.dappbot_private_api_iam.arn
    handler          = "index.privateHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 10

    environment {
      variables = {
        COGNITO_USER_POOL = aws_cognito_user_pool.registered_users.id
        COGNITO_CLIENT_ID = aws_cognito_user_pool_client.api_client.id
        DDB_TABLE         = aws_dynamodb_table.dapp_table.id
        DNS_ROOT          = local.created_dns_root
        SQS_QUEUE         = aws_sqs_queue.dappbot.id
        DAPPHUB_DNS       = local.dapphub_dns
      }
    }

    depends_on = [null_resource.dappbot_private_api_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
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
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dapphub-view-lambda-${var.subdomain}"
    role             = aws_iam_role.dappbot_public_api_iam.arn
    handler          = "index.publicHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 5

    environment {
      variables = {
        DDB_TABLE = aws_dynamodb_table.dapp_table.id
      }
    }

    depends_on = [null_resource.dappbot_public_api_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT AUTH LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
  # Wait ensures that the role is fully created when Lambda tries to assume it.
  resource "null_resource" "dappbot_auth_api_wait" {
    provisioner "local-exec" {
      command = "sleep 10"
    }
    depends_on = [aws_iam_role.dappbot_auth_api_iam]
  }

  resource "aws_lambda_function" "dappbot_auth_api_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dappbot-auth-lambda-${var.subdomain}"
    role             = aws_iam_role.dappbot_auth_api_iam.arn
    handler          = "index.authHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 5

    environment {
      variables = {
        COGNITO_USER_POOL = aws_cognito_user_pool.registered_users.id
        COGNITO_CLIENT_ID = aws_cognito_user_pool_client.api_client.id
      }
    }

    depends_on = [null_resource.dappbot_auth_api_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT CONFIG LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
  # Wait ensures that the role is fully created when Lambda tries to assume it.
  resource "null_resource" "dappbot_config_api_wait" {
    provisioner "local-exec" {
      command = "sleep 10"
    }
    depends_on = [aws_iam_role.dappbot_config_api_iam]
  }

  resource "aws_lambda_function" "dappbot_config_api_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dappbot-config-lambda-${var.subdomain}"
    role             = aws_iam_role.dappbot_config_api_iam.arn
    handler          = "index.configHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 10

    environment {
      variables = {
        COGNITO_USER_POOL = aws_cognito_user_pool.registered_users.id
        COGNITO_CLIENT_ID = aws_cognito_user_pool_client.api_client.id
      }
    }

    depends_on = [null_resource.dappbot_config_api_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
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

  module "dappbot_manager_lambda_pipeline" {
    source = "git@github.com:Eximchain/terraform-aws-lambda-cd-pipeline.git"

    id = "manager-${var.subdomain}"

    github_lambda_repo    = "dappbot-manager-lambda"
    github_lambda_branch  = var.dappbot_manager_lambda_branch_override != "" ? var.dappbot_manager_lambda_branch_override : var.lambda_default_branch
    build_command         = "npm install && npm run build"

    deployment_package_filename    = "dappbot-manager-lambda.zip"
    deployment_package_bucket_name = aws_s3_bucket.lambda_deployment_packages.bucket

    deployment_target_lambdas = [
      aws_lambda_function.dappbot_manager_lambda.function_name,
      aws_lambda_function.dappbot_manager_deadletter_lambda.function_name
    ]

    aws_region            = var.aws_region
    force_destroy_buckets = true
  }

  resource "aws_lambda_function" "dappbot_manager_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dappbot-manager-${var.subdomain}"
    role             = aws_iam_role.dappbot_manager_iam.arn
    handler          = "index.handler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
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

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
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
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dappbot-manager-deadletter-${var.subdomain}"
    role             = aws_iam_role.dappbot_deadletter_iam.arn
    handler          = "index.deadLetterHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
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

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
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

  module "dappbot_event_listener_lambda_pipeline" {
    source = "git@github.com:Eximchain/terraform-aws-lambda-cd-pipeline.git"

    id = "event-listener-${var.subdomain}"

    github_lambda_repo    = "dappbot-event-listener-lambda"
    github_lambda_branch  = var.dappbot_event_listener_lambda_branch_override != "" ? var.dappbot_event_listener_lambda_branch_override : var.lambda_default_branch
    build_command         = "npm install && npm run build"

    deployment_package_filename    = "dappbot-event-listener-lambda.zip"
    deployment_package_bucket_name = aws_s3_bucket.lambda_deployment_packages.bucket

    deployment_target_lambdas = [aws_lambda_function.dappbot_event_listener_lambda.function_name]

    aws_region            = var.aws_region
    force_destroy_buckets = true
  }

  resource "aws_lambda_function" "dappbot_event_listener_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "dappbot-event-listener-lambda-${var.subdomain}"
    role             = aws_iam_role.dappbot_event_listener_iam.arn
    handler          = "index.handler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 900
    memory_size      = 256

    environment {
      variables = {
        DAPP_TABLE                      = aws_dynamodb_table.dapp_table.id
        LAPSED_USERS_TABLE              = aws_dynamodb_table.lapsed_users_table.id
        SQS_QUEUE                       = aws_sqs_queue.dappbot.id
        R53_HOSTED_ZONE_ID              = data.aws_route53_zone.hosted_zone.zone_id
        DNS_ROOT                        = local.created_dns_root
        CODEBUILD_ID                    = aws_codebuild_project.dappbot_builder.id
        PIPELINE_ROLE_ARN               = aws_iam_role.dappbot_codepipeline_iam.arn
        ARTIFACT_BUCKET                 = aws_s3_bucket.artifact_bucket.id
        DAPPSEED_BUCKET                 = aws_s3_bucket.dappseed_bucket.id
        WILDCARD_CERT_ARN               = local.wildcard_cert_arn
        COGNITO_USER_POOL               = aws_cognito_user_pool.registered_users.id
        SENDGRID_API_KEY                = var.sendgrid_key
        GITHUB_TOKEN                    = var.service_github_token
        PAYMENT_LAPSED_GRACE_PERIOD_HRS = var.payment_lapsed_grace_period_hours
      }
    }

    depends_on = [null_resource.dappbot_event_listener_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# PAYMENT STRIPE LAMBDA FUNCTION SHARED WAIT
# ---------------------------------------------------------------------------------------------------------------------
  resource "null_resource" "payment_gateway_stripe_wait" {
    provisioner "local-exec" {
      command = "sleep 10"
    }
    depends_on = [aws_iam_role.stripe_payment_gateway_lambda_iam]
  }

  module "payment_gateway_stripe_lambda_pipeline" {
    source = "git@github.com:Eximchain/terraform-aws-lambda-cd-pipeline.git"

    id = "payment-gateway-stripe-${var.subdomain}"

    github_lambda_repo    = "payment-gateway-stripe-lambda"
    github_lambda_branch  = var.payment_gateway_stripe_lambda_branch_override != "" ? var.payment_gateway_stripe_lambda_branch_override : var.lambda_default_branch
    build_command         = "npm install && npm run build"

    deployment_package_filename    = "payment-gateway-stripe-lambda.zip"
    deployment_package_bucket_name = aws_s3_bucket.lambda_deployment_packages.bucket

    deployment_target_lambdas = [
      aws_lambda_function.stripe_signup_gateway_lambda.function_name,
      aws_lambda_function.stripe_management_gateway_lambda.function_name,
      aws_lambda_function.stripe_webhook_gateway_lambda.function_name
    ]

    aws_region            = var.aws_region
    force_destroy_buckets = true
  }

# ---------------------------------------------------------------------------------------------------------------------
# PAYMENT STRIPE SIGNUP LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
  resource "aws_lambda_function" "stripe_signup_gateway_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "stripe-signup-gateway-lambda-${var.subdomain}"
    role             = aws_iam_role.stripe_payment_gateway_lambda_iam.arn
    handler          = "index.signupHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 900

    environment {
      variables = {
        COGNITO_USER_POOL       = aws_cognito_user_pool.registered_users.id
        STRIPE_API_KEY          = var.stripe_api_key
        EXIMCHAIN_ACCOUNTS_ONLY = var.eximchain_accounts_only
      }
    }

    depends_on = [null_resource.payment_gateway_stripe_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# PAYMENT STRIPE MANAGEMENT LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
  resource "aws_lambda_function" "stripe_management_gateway_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "stripe-management-gateway-lambda-${var.subdomain}"
    role             = aws_iam_role.stripe_payment_gateway_lambda_iam.arn
    handler          = "index.managementHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 900

    environment {
      variables = {
        DAPP_TABLE        = aws_dynamodb_table.dapp_table.id
        COGNITO_USER_POOL = aws_cognito_user_pool.registered_users.id
        SNS_TOPIC_ARN     = aws_sns_topic.payment_events.arn
        STRIPE_API_KEY    = var.stripe_api_key
      }
    }

    depends_on = [null_resource.payment_gateway_stripe_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# PAYMENT STRIPE WEBHOOK LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
  resource "aws_lambda_function" "stripe_webhook_gateway_lambda" {
    s3_bucket        = aws_s3_bucket.lambda_deployment_packages.bucket
    s3_key           = aws_s3_bucket_object.default_function.key
    function_name    = "stripe-webhook-gateway-lambda-${var.subdomain}"
    role             = aws_iam_role.stripe_payment_gateway_lambda_iam.arn
    handler          = "index.webhookHandler"
    source_code_hash = filebase64sha256(aws_s3_bucket_object.default_function.source)
    runtime          = "nodejs10.x"
    timeout          = 900

    environment {
      variables = {
        SNS_TOPIC_ARN         = aws_sns_topic.payment_events.arn
        STRIPE_API_KEY        = var.stripe_api_key
        STRIPE_WEBHOOK_SECRET = var.stripe_webhook_secret
        SENDGRID_API_KEY      = var.sendgrid_key
        MANAGER_SPA_DNS       = local.dappbot_manager_dns
      }
    }

    depends_on = [null_resource.payment_gateway_stripe_wait]

    tags = local.default_tags

    lifecycle {
      ignore_changes = [
        "source_code_hash",
        "last_modified"
      ]
    }
  }

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

    mfa_configuration = "OPTIONAL"

    username_attributes      = ["email"]
    auto_verified_attributes = ["email"]

    admin_create_user_config {
      allow_admin_create_user_only = true
      unused_account_validity_days = 7

      invite_message_template {
        email_subject = local.invitation_email_subject
        email_message = local.invitation_email_html
        sms_message   = local.invitation_sms
      }
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

    sms_configuration {
      external_id    = "cognito-sms-${var.subdomain}"
      sns_caller_arn = aws_iam_role.cognito_sms.arn
    }

    // Workaround for the inability to enable software token MFA with an attribute
    // Should be removed and replaced with such an attribute when it exists
    // Note this will NOT work on an already existing user pool
    provisioner "local-exec" {
      command = "aws cognito-idp set-user-pool-mfa-config --user-pool-id ${self.id} --software-token-mfa-configuration Enabled=true --mfa-configuration ${self.mfa_configuration}"
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
    allowed_oauth_scopes = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]

    allowed_oauth_flows_user_pool_client = true

    callback_urls = [local.redirect_uri]
    logout_urls          = [local.redirect_uri]
    default_redirect_uri = local.redirect_uri

    supported_identity_providers = ["COGNITO"]

    read_attributes  = ["email", "custom:num_dapps", "custom:standard_limit", "custom:professional_limit", "custom:enterprise_limit", "custom:payment_provider", "custom:payment_status"]
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
      REACT_APP_DAPPBOT_API_ENDPOINT       = "https://${local.api_domain}"
      REACT_APP_AWS_REGION                 = var.aws_region
      REACT_APP_USER_POOL_ID               = aws_cognito_user_pool.registered_users.id
      REACT_APP_STRIPE_PUBLISHABLE_API_KEY = var.stripe_public_key
      REACT_APP_USER_POOL_CLIENT_ID        = aws_cognito_user_pool_client.api_client.id
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

  # Subscriptions
  resource "aws_sns_topic_subscription" "cleanup_lambda" {
    topic_arn = aws_sns_topic.cleanup_event.arn
    protocol  = "lambda"
    endpoint  = aws_lambda_function.dappbot_event_listener_lambda.arn
  }

  # Permissions
  resource "aws_lambda_permission" "sns_invoke_cleanup_lambda" {
    statement_id  = "CleanupAllowExecutionFromSns"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.dappbot_event_listener_lambda.function_name
    principal     = "sns.amazonaws.com"

    source_arn = aws_sns_topic.cleanup_event.arn
  }

  resource "aws_sns_topic_policy" "cloudwatch_events_publish_cleanup" {
    arn    = aws_sns_topic.cleanup_event.arn
    policy = data.aws_iam_policy_document.cloudwatch_events_publish_cleanup.json
  }

  data "aws_iam_policy_document" "cloudwatch_events_publish_cleanup" {
    statement {
      sid = "1"

      effect  = "Allow"

      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.cleanup_event.arn]

      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# PAYMENT EVENTS
# ---------------------------------------------------------------------------------------------------------------------
  resource "aws_sns_topic" "payment_events" {
    name = "dappbot-payment-events-${var.subdomain}"
  }

  # Subscriptions
  resource "aws_sns_topic_subscription" "payment_events_lambda" {
    topic_arn = aws_sns_topic.payment_events.arn
    protocol  = "lambda"
    endpoint  = aws_lambda_function.dappbot_event_listener_lambda.arn
  }

  # Permissions
  resource "aws_lambda_permission" "sns_payment_events_invoke_event_listener_lambda" {
    statement_id  = "PaymentEventsAllowExecutionFromSns"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.dappbot_event_listener_lambda.function_name
    principal     = "sns.amazonaws.com"

    source_arn = aws_sns_topic.payment_events.arn
  }

# ---------------------------------------------------------------------------------------------------------------------
# CD PIPELINE NOTIFICATION TOPIC
# ---------------------------------------------------------------------------------------------------------------------
  resource "aws_sns_topic" "cd_pipeline_notifications" {
    name = "cd-pipeline-notifications-${var.subdomain}"
  }

  resource "aws_sns_topic_policy" "cloudwatch_events_publish_cd_pipeline_notifications" {
    arn    = aws_sns_topic.cd_pipeline_notifications.arn
    policy = data.aws_iam_policy_document.cloudwatch_events_publish_cd_pipeline_notifications.json
  }

  data "aws_iam_policy_document" "cloudwatch_events_publish_cd_pipeline_notifications" {
    statement {
      effect  = "Allow"
      actions = ["SNS:Publish"]

      principals {
        type        = "Service"
        identifiers = ["events.amazonaws.com"]
      }

      resources = [aws_sns_topic.cd_pipeline_notifications.arn]
    }
  }

# ---------------------------------------------------------------------------------------------------------------------
# CD PIPELINE NOTIFICATION EVENTS
# ---------------------------------------------------------------------------------------------------------------------
  resource "aws_cloudwatch_event_rule" "cd_pipeline_complete" {
    name        = "cd-pipeline-complete-${var.subdomain}"
    description = "Triggers on CD pipeline run completion"

    event_pattern = <<PATTERN
  {
    "source": [
      "aws.codepipeline"
    ],
    "detail-type": [
      "CodePipeline Pipeline Execution State Change"
    ],
    "detail": {
      "state": [
        "SUCCEEDED",
        "FAILED"
      ],
      "pipeline": [
        "${module.dappbot_api_lambda_pipeline.pipeline_name}",
        "${module.dappbot_manager_lambda_pipeline.pipeline_name}",
        "${module.dappbot_event_listener_lambda_pipeline.pipeline_name}",
        "${module.payment_gateway_stripe_lambda_pipeline.pipeline_name}",
        "${module.dapphub_website.pipeline_name}",
        "${module.dappbot_manager.pipeline_name}"
      ]
    }
  }
  PATTERN
  }

  resource "aws_cloudwatch_event_target" "cd_pipeline_complete" {
    rule      = aws_cloudwatch_event_rule.cd_pipeline_complete.name
    target_id = "SendToSNS"
    arn       = aws_sns_topic.cd_pipeline_notifications.arn

    input_transformer {
      input_paths = {
        pipeline = "$.detail.pipeline"
        state    = "$.detail.state"
      }

      input_template = <<EOF
  {
    "subject": "Pipeline Run Complete",
    "stage": "${local.stage}",
    "pipeline": <pipeline>,
    "state": <state>
  }
  EOF
    }
  }