# ---------------------------------------------------------------------------------------------------------------------
# IAM FOR DAPPBOT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_lambda_iam" {
  name = "dappbot-lambda-iam-${var.subdomain}"

  assume_role_policy = "${data.aws_iam_policy_document.dappbot_lambda_assume_role.json}"

  tags = "${local.default_tags}"
}

data "aws_iam_policy_document" "dappbot_lambda_assume_role" {
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
resource "aws_iam_policy" "dappbot_allow_cloudwatch" {
  name = "allow-cloudwatch-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_cloudwatch.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_cloudwatch" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_cloudwatch.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_cloudwatch" {
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
resource "aws_iam_policy" "dappbot_allow_dynamodb" {
  name = "allow-dynamodb-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_dynamodb.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_dynamodb" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_dynamodb.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_dynamodb" {
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
resource "aws_iam_policy" "dappbot_allow_s3" {
  name = "allow-s3-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_s3.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_s3" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_s3.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_s3" {
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
      "s3:PutBucketCORS",
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
        "${aws_s3_bucket.dappseed_bucket.arn}/*",
        "${aws_s3_bucket.artifact_bucket.arn}"
      ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM CLOUDFRONT ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_allow_cloudfront" {
  name = "allow-cloudfront-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_cloudfront.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_cloudfront" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_cloudfront.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_cloudfront" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:TagResource",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:ListDistributions",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateInvalidation"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM ROUTE53 ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_allow_route53" {
  name = "allow-route53-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_route53.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_route53" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_route53.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_route53" {
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
resource "aws_iam_policy" "dappbot_allow_codepipeline" {
  name = "allow-codepipeline-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_codepipeline.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_codepipeline" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_codepipeline.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_codepipeline" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "codepipeline:CreatePipeline",
      "codepipeline:DeletePipeline",
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutJobFailureResult"
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM IAM ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_allow_lambda_iam" {
  name = "allow-iam-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_iam.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_lambda_iam" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_lambda_iam.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_iam" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]
    resources = ["${aws_iam_role.dappbot_codepipeline_iam.arn}"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA IAM COGNITO ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_allow_lambda_cognito" {
  name = "allow-cognito-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_cognito.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_lambda_cognito" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_lambda_cognito.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_cognito" {
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
# LAMBDA IAM SQS ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_allow_sqs" {
  name = "allow-sqs-dappbot-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_allow_sqs.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_allow_sqs" {
  role       = "${aws_iam_role.dappbot_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_allow_sqs.arn}"
}

data "aws_iam_policy_document" "dappbot_allow_sqs" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [
      "${aws_sqs_queue.dappbot.arn}",
      "${aws_sqs_queue.dappbot_deadletter.arn}"
    ]
  }
}