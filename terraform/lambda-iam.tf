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