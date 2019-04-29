# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 2.2"
}

provider "local" {
  version = "~> 1.2"
}

provider "null" {
  version = "~> 2.1"
}

locals {
    s3_bucket_arn_pattern = "arn:aws:s3:::exim-abi-clerk-*"
    default_tags {
      Application = "AbiClerk"
      ManagedBy   = "Terraform"
    }
    created_dns_root = ".${var.subdomain}.${var.root_domain}"
    cert_arn = "${var.create_wildcard_cert ? aws_acm_certificate.cloudfront_cert.arn : element(coalescelist(data.aws_acm_certificate.cloudfront_cert.*.arn, list("")), 0)}"
    image_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.codebuild_image}"
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "cert" {
  domain      = "${var.root_domain}"
  most_recent = true
}

data "aws_route53_zone" "hosted_zone" {
  name = "${var.root_domain}."
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM FOR LAMBDA
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "abi_clerk_lambda_iam" {
  name = "abi-clerk-lambda-iam-${var.subdomain}"

  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.json}"

  tags = "${local.default_tags}"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM CLOUDWATCH ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_cloudwatch" {
  name = "allow-cloudwatch-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_cloudwatch.json}"
}

resource "aws_iam_role_policy_attachment" "allow_cloudwatch" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_cloudwatch.arn}"
}

data "aws_iam_policy_document" "lambda_allow_cloudwatch" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM DYNAMODB ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_dynamodb" {
  name = "allow-dynamodb-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_dynamodb.json}"
}

resource "aws_iam_role_policy_attachment" "allow_dynamodb" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_dynamodb.arn}"
}

data "aws_iam_policy_document" "lambda_allow_dynamodb" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable"
    ]
    resources = ["${aws_dynamodb_table.dapp_table.arn}"]
  }

  statement {
      sid = "2"

      effect = "Allow"

      actions = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
      ]
      resources = [
        "${aws_dynamodb_table.dapp_table.arn}",
        "${aws_dynamodb_table.dapp_table.arn}/*"
      ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM S3 ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_s3" {
  name = "allow-s3-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_s3.json}"
}

resource "aws_iam_role_policy_attachment" "allow_s3" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_s3.arn}"
}

data "aws_iam_policy_document" "lambda_allow_s3" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketWebsite",
      "s3:GetBucketWebsite",
      "s3:DeleteBucketWebsite",
      "s3:GetBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketTagging",
      "s3:GetBucketAcl",
      "s3:PutBucketAcl",
      "s3:GetObjectAcl",
      "s3:PutObjectAcl"
    ]
    resources = [
      "${local.s3_bucket_arn_pattern}",
      "${aws_s3_bucket.dappseed_bucket.arn}"
    ]
  }

  statement {
      sid = "2"

      effect = "Allow"

      actions = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListObjects"
      ]
      resources = [
        "${local.s3_bucket_arn_pattern}/*",
        "${aws_s3_bucket.dappseed_bucket.arn}/*"
      ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM CLOUDFRONT ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_cloudfront" {
  name = "allow-cloudfront-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_cloudfront.json}"
}

resource "aws_iam_role_policy_attachment" "allow_cloudfront" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_cloudfront.arn}"
}

data "aws_iam_policy_document" "lambda_allow_cloudfront" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:TagResource",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM ROUTE53 ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_route53" {
  name = "allow-route53-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_route53.json}"
}

resource "aws_iam_role_policy_attachment" "allow_route53" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_route53.arn}"
}

data "aws_iam_policy_document" "lambda_allow_route53" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM CODEPIPELINE ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_lambda_codepipeline" {
  name = "allow-codepipeline-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_codepipeline.json}"
}

resource "aws_iam_role_policy_attachment" "allow_lambda_codepipeline" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_lambda_codepipeline.arn}"
}

data "aws_iam_policy_document" "lambda_allow_codepipeline" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "codepipeline:CreatePipeline",
      "codepipeline:DeletePipeline"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM IAM ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_lambda_iam" {
  name = "allow-iam-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_iam.json}"
}

resource "aws_iam_role_policy_attachment" "allow_lambda_iam" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_lambda_iam.arn}"
}

data "aws_iam_policy_document" "lambda_allow_iam" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]
    resources = ["${aws_iam_role.abi_clerk_codepipeline_iam.arn}"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM COGNITO ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_lambda_cognito" {
  name = "allow-cognito-abi-clerk-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.lambda_allow_cognito.json}"
}

resource "aws_iam_role_policy_attachment" "allow_lambda_cognito" {
  role       = "${aws_iam_role.abi_clerk_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.allow_lambda_cognito.arn}"
}

data "aws_iam_policy_document" "lambda_allow_cognito" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cognito-idp:AdminGetUser"
    ]
    resources = ["${aws_cognito_user_pool.registered_users.arn}"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SHARED S3 BUCKETS & KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "abi-clerk-artifacts-${var.subdomain}"
  acl           = "private"
  force_destroy = true

  tags = "${local.default_tags}"
}

resource "aws_s3_bucket" "dappseed_bucket" {
  bucket        = "abi-clerk-dappseeds-${var.subdomain}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }

  tags = "${local.default_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

# Wait ensures that the role is fully created when Lambda tries to assume it.
resource "null_resource" "lambda_wait" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
  depends_on = ["aws_iam_role.abi_clerk_lambda_iam"]
}

resource "aws_lambda_function" "abi_clerk_lambda" {
  filename         = "abi-clerk-lambda.zip"
  function_name    = "abi-clerk-lambda-${var.subdomain}"
  role             = "${aws_iam_role.abi_clerk_lambda_iam.arn}"
  handler          = "index.handler"
  source_code_hash = "${base64sha256(file("abi-clerk-lambda.zip"))}"
  runtime          = "nodejs8.10"
  timeout          = 900

  environment {
    variables {
      DDB_TABLE          = "${aws_dynamodb_table.dapp_table.id}"
      R53_HOSTED_ZONE_ID = "${data.aws_route53_zone.hosted_zone.zone_id}"
      DNS_ROOT           = "${local.created_dns_root}"
      CODEBUILD_ID       = "${aws_codebuild_project.abi_clerk_builder.id}",
      PIPELINE_ROLE_ARN  = "${aws_iam_role.abi_clerk_codepipeline_iam.arn}",
      ARTIFACT_BUCKET    = "${aws_s3_bucket.artifact_bucket.id}",
      DAPPSEED_BUCKET    = "${aws_s3_bucket.dappseed_bucket.id}",
      CERT_ARN           = "${local.cert_arn}"
      COGNITO_USER_POOL  = "${aws_cognito_user_pool.registered_users.id}"
    }
  }

  depends_on = ["null_resource.lambda_wait"]

  tags = "${local.default_tags}"
}

resource "aws_lambda_permission" "api_gateway_invoke_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.abi_clerk_lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.abi_clerk_api.execution_arn}/*/*/*"
}

# ---------------------------------------------------------------------------------------------------------------------
# TODO: Add S3 bucket for Lambda fxn (env var) to support full CD
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "abi_clerk_codepipeline_iam" {
  name = "abi-clerk-codepipeline-role-${var.subdomain}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = "${local.default_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE IAM ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codepipeline" {
  name = "allow-s3-abi-clerk-codepipeline-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.codepipeline.json}"
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = "${aws_iam_role.abi_clerk_codepipeline_iam.id}"
  policy_arn = "${aws_iam_policy.codepipeline.arn}"
}

data "aws_iam_policy_document" "codepipeline" {
  version = "2012-10-17"

  statement {
    sid = "S3Access"

    effect = "Allow"

    actions = [
      "s3:*"
    ]

    resources = [
      "${local.s3_bucket_arn_pattern}",
      "${local.s3_bucket_arn_pattern}/*",
      "${aws_s3_bucket.dappseed_bucket.arn}",
      "${aws_s3_bucket.dappseed_bucket.arn}/*",
      "${aws_s3_bucket.artifact_bucket.arn}",
      "${aws_s3_bucket.artifact_bucket.arn}/*"
    ]
  }

  statement {
    sid = "CodeBuild"

    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]

    resources = ["*"]
  }

  statement {
    sid = "CloudWatchLogsPolicy"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    
    resources = [
      "*"
    ]
  }
  
  statement {
    sid = "ReadOnlyECR"
    
    effect = "Allow"
    
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage"
    ]
    
    resources = ["*"]
  }

}

# ---------------------------------------------------------------------------------------------------------------------
# CODEBUILD PROJECT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_codebuild_project" "abi_clerk_builder" {
  name = "abi-clerk-builder-${var.subdomain}"
  build_timeout = 10
  service_role = "${aws_iam_role.abi_clerk_codepipeline_iam.arn}"

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "${local.image_url}"
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      name  = "NPM_USER"
      value = "${var.npm_user}"
    }

    environment_variable {
      name  = "NPM_PASS"
      value = "${var.npm_pass}"
    }

    environment_variable {
      name  = "NPM_EMAIL"
      value = "${var.npm_email}"
    }
  }

  artifacts {
    type = "CODEPIPELINE"
    encryption_disabled = true
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "${data.local_file.buildspec.content}"
  }

  tags = "${local.default_tags}"
}

data "local_file" "buildspec" {
  filename = "${path.module}/buildspec.yml"
}

# ---------------------------------------------------------------------------------------------------------------------
# ACM CERT for CLOUDFRONT
# ---------------------------------------------------------------------------------------------------------------------
data "aws_acm_certificate" "cloudfront_cert" {
  count  = "${var.create_wildcard_cert ? 0 : 1}"

  domain = "*.${var.subdomain}.${var.root_domain}"
}

resource "aws_acm_certificate" "cloudfront_cert" {
  count = "${var.create_wildcard_cert ? 1 : 0}"

  domain_name       = "*.${var.subdomain}.${var.root_domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cloudfront_wildcard" {
  count = "${var.create_wildcard_cert ? 1 : 0}"

  name    = "${aws_acm_certificate.cloudfront_cert.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.cloudfront_cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.hosted_zone.zone_id}"
  records = ["${aws_acm_certificate.cloudfront_cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cloudfront_validation" {
  count = "${var.create_wildcard_cert ? 1 : 0}"

  certificate_arn         = "${aws_acm_certificate.cloudfront_cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cloudfront_wildcard.fqdn}"]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "abi_clerk_api" {
  name        = "abi-clerk-${var.subdomain}"
  description = "Proxy to handle requests to the ABI Clerk API"
}

resource "aws_api_gateway_resource" "abi_clerk_resource" {
  rest_api_id = "${aws_api_gateway_rest_api.abi_clerk_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.abi_clerk_api.root_resource_id}"
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "abi_clerk_method" {
  rest_api_id   = "${aws_api_gateway_rest_api.abi_clerk_api.id}"
  resource_id   = "${aws_api_gateway_resource.abi_clerk_resource.id}"
  http_method   = "ANY"

  authorization = "COGNITO_USER_POOLS"
  authorizer_id = "${aws_api_gateway_authorizer.api_auth.id}"

  request_parameters {
    "method.request.path.proxy" = true
  }
}
resource "aws_api_gateway_integration" "abi_clerk_integration" {
  rest_api_id = "${aws_api_gateway_rest_api.abi_clerk_api.id}"
  resource_id = "${aws_api_gateway_resource.abi_clerk_resource.id}"
  http_method = "${aws_api_gateway_method.abi_clerk_method.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.abi_clerk_lambda.arn}/invocations"
 
  request_parameters {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

resource "aws_api_gateway_deployment" "abi_clerk_deploy_test_stage" {
  depends_on = ["aws_api_gateway_integration.abi_clerk_integration"]

  rest_api_id = "${aws_api_gateway_rest_api.abi_clerk_api.id}"
  stage_name  = "test"
}

resource "aws_api_gateway_authorizer" "api_auth" {
  name          = "abi-clerk-auth-${var.subdomain}"
  rest_api_id   = "${aws_api_gateway_rest_api.abi_clerk_api.id}"
  provider_arns = ["${aws_cognito_user_pool.registered_users.arn}"]

  identity_source = "method.request.header.Authorization"
  type            = "COGNITO_USER_POOLS"
}

# ---------------------------------------------------------------------------------------------------------------------
# CUSTOM DNS NAME
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_domain_name" "domain" {
  certificate_arn = "${data.aws_acm_certificate.cert.arn}"
  domain_name     = "${var.subdomain}.${var.root_domain}"
}

resource "aws_api_gateway_base_path_mapping" "base_path_mapping" {
  api_id = "${aws_api_gateway_rest_api.abi_clerk_api.id}"
  
  domain_name = "${aws_api_gateway_domain_name.domain.domain_name}"
}

resource "aws_route53_record" "example" {
  name    = "${aws_api_gateway_domain_name.domain.domain_name}"
  type    = "A"
  zone_id = "${data.aws_route53_zone.hosted_zone.zone_id}"

  alias {
    evaluate_target_health = true
    name                   = "${aws_api_gateway_domain_name.domain.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.domain.cloudfront_zone_id}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMODB TABLES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_dynamodb_table" "dapp_table" {
  name           = "abi-clerk-dapps-${var.subdomain}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "DappName"

  global_secondary_index {
    name     = "OwnerEmailIndex"
    hash_key = "OwnerEmail"

    write_capacity = 1
    read_capacity  = 1

    projection_type = "KEYS_ONLY"
  }

  attribute {
    name = "DappName"
    type = "S"
  }

  attribute {
    name = "OwnerEmail"
    type = "S"
  }

  tags = "${local.default_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# COGNITO RESOURCES FOR AUTH
# ---------------------------------------------------------------------------------------------------------------------
locals {
  redirect_uri = "https://www.eximchain.com"
}
resource "aws_cognito_user_pool" "registered_users" {
  name = "abi-clerk-users-${var.subdomain}"

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

  schema {
    name = "num_dapps"

    attribute_data_type      = "Number"
    # TODO: Understand this attribute
    developer_only_attribute = true
    mutable                  = true

    # Custom attributes cannot be required
    required                 = false

    number_attribute_constraints {
      min_value = 0
      max_value = 1000
    }
  }

  tags = "${local.default_tags}"
}

resource "aws_cognito_user_pool_domain" "cognito_domain" {
  domain       = "eximtest-abi-clerk-${var.subdomain}"
  user_pool_id = "${aws_cognito_user_pool.registered_users.id}"
}

resource "aws_cognito_user_pool_client" "api_client" {
  name         = "abi-clerk-client-${var.subdomain}"
  user_pool_id = "${aws_cognito_user_pool.registered_users.id}"

  allowed_oauth_flows  = ["code", "implicit"]
  allowed_oauth_scopes = ["email", "openid", "profile"]

  allowed_oauth_flows_user_pool_client = true

  callback_urls        = ["${local.redirect_uri}"]
  logout_urls          = ["${local.redirect_uri}"]
  default_redirect_uri = "${local.redirect_uri}"

  supported_identity_providers = ["COGNITO"]

  read_attributes = ["email"]

  # Allows us to skip the challenge flow for script-based testing
  explicit_auth_flows = ["USER_PASSWORD_AUTH"]
}