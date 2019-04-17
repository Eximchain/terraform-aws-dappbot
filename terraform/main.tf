# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
    region  = "${var.aws_region}"
    version = "~> 2.2"
}

locals {
    s3_bucket_arn_pattern = "arn:aws:s3:::exim-abi-clerk-*"
    created_dns_root = ".test-subdomain.${var.root_domain}"
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
  name = "abi-clerk-lambda-iam"

  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.json}"
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
  name = "allow-cloudwatch-abi-clerk-lambda"

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
  name = "allow-dynamodb-abi-clerk-lambda"

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
          "dynamodb:UpdateItem"
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
  name = "allow-s3-abi-clerk-lambda"

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
  name = "allow-cloudfront-abi-clerk-lambda"

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
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM ROUTE53 ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "allow_route53" {
  name = "allow-route53-abi-clerk-lambda"

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
  name = "allow-codepipeline-abi-clerk-lambda"

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
  name = "allow-iam-abi-clerk-lambda"

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
# SHARED S3 BUCKETS & KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "abi-clerk-artifacts"
  acl           = "private"
  force_destroy = true
}

resource "aws_s3_bucket" "dappseed_bucket" {
  bucket        = "abi-clerk-dappseeds"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lambda_function" "abi_clerk_lambda" {
  filename         = "abi-clerk-lambda.zip"
  function_name    = "abi-clerk-lambda"
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
      DAPPSEED_BUCKET    = "${aws_s3_bucket.dappseed_bucket.id}"
    }
  }
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
  name = "codepipeline-role"

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
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE IAM ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codepipeline" {
  name = "allow-s3-abi-clerk-codepipeline"

  policy = "${data.aws_iam_policy_document.codepipeline.json}"
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = "${aws_iam_role.abi_clerk_codepipeline_iam.id}"
  policy_arn = "${aws_iam_policy.codepipeline.arn}"
}

data "aws_iam_policy_document" "codepipeline" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "s3:*"
    ]

    resources = [
      "${local.s3_bucket_arn_pattern}",
      "${local.s3_bucket_arn_pattern}/*"
    ]
  }

  statement {
    sid = "2"

    effect = "Allow"

    // TODO: Determine if these are sufficient read permissions
    //
    // actions = [
    //   "s3:GetObject",
    //   "s3:GetObjectVersion",
    //   "s3:GetBucketVersioning"
    // ]
    //
    resources = [
      "${aws_s3_bucket.dappseed_bucket.arn}",
      "${aws_s3_bucket.dappseed_bucket.arn}/*",
      "${aws_s3_bucket.artifact_bucket.arn}",
      "${aws_s3_bucket.artifact_bucket.arn}/*"
    ]

    actions = [
      "s3:*"
    ]

    // TODO: Limit this to something a little less reckless
    // resources = [
    //   "*"
    // ]

  }

  statement {
    sid = "3"

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
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEBUILD PROJECT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_codebuild_project" "abi_clerk_builder" {
  name = "abi_clerk_builder"
  build_timeout = 10
  service_role = "${aws_iam_role.abi_clerk_codepipeline_iam.arn}"

  environment {
    type = "LINUX_CONTAINER"
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image = "aws/codebuild/nodejs:10.14.1-1.7.0"

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
}

data "local_file" "buildspec" {
  filename = "${path.module}/buildspec.yml"
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "abi_clerk_api" {
  name        = "abi-clerk"
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
  authorization = "NONE"

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
  name           = "abi-clerk-dapps"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "DappName"

  attribute {
    name = "DappName"
    type = "S"
  }
}