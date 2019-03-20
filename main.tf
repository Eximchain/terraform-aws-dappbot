# ---------------------------------------------------------------------------------------------------------------------
# PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
    region  = "${var.aws_region}"
    version = "~> 2.2"
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
    resources = ["${aws_dynamodb_table.kv_table.arn}"]
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
        "${aws_dynamodb_table.kv_table.arn}",
        "${aws_dynamodb_table.kv_table.arn}/*"
      ]
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

  environment {
    variables {
      DDB_TABLE = "${aws_dynamodb_table.kv_table.id}"
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
resource "aws_dynamodb_table" "kv_table" {
  name           = "abi-clerk-kv-test"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "Key"

  attribute {
    name = "Key"
    type = "S"
  }
}