# ---------------------------------------------------------------------------------------------------------------------
# IAM FOR DAPPBOT API
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_api_lambda_iam" {
  name = "dappbot-api-lambda-iam-${var.subdomain}"

  assume_role_policy = "${data.aws_iam_policy_document.dappbot_api_lambda_assume_role.json}"

  tags = "${local.default_tags}"
}

data "aws_iam_policy_document" "dappbot_api_lambda_assume_role" {
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
# LAMBDA IAM DYNAMODB ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_api_allow_dynamodb" {
  name = "allow-dynamodb-dappbot-api-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_api_allow_dynamodb.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_api_allow_dynamodb" {
  role       = "${aws_iam_role.dappbot_api_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_api_allow_dynamodb.arn}"
}

data "aws_iam_policy_document" "dappbot_api_allow_dynamodb" {
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
# LAMBDA IAM CLOUDWATCH ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dappbot_api_allow_cloudwatch" {
  name = "allow-cloudwatch-dappbot-api-lambda-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.dappbot_api_allow_cloudwatch.json}"
}

resource "aws_iam_role_policy_attachment" "dappbot_api_allow_cloudwatch" {
  role       = "${aws_iam_role.dappbot_api_lambda_iam.id}"
  policy_arn = "${aws_iam_policy.dappbot_api_allow_cloudwatch.arn}"
}

data "aws_iam_policy_document" "dappbot_api_allow_cloudwatch" {
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