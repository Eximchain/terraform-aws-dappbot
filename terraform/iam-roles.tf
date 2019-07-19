# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT PRIVATE API ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_private_api_iam" {
  name = "dappbot-api-private-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_private_api_cloudwatch" {
  role       = aws_iam_role.dappbot_private_api_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# DynamoDB
resource "aws_iam_role_policy_attachment" "dappbot_private_api_dynamodb" {
  role       = aws_iam_role.dappbot_private_api_iam.id
  policy_arn = aws_iam_policy.dynamodb_dapp_table_read_write.arn
}

# SQS
resource "aws_iam_role_policy_attachment" "dappbot_private_api_sqs" {
  role       = aws_iam_role.dappbot_private_api_iam.id
  policy_arn = aws_iam_policy.sqs_send_message_dappbot.arn
}

# Cognito
resource "aws_iam_role_policy_attachment" "dappbot_private_api_cognito" {
  role       = aws_iam_role.dappbot_private_api_iam.id
  policy_arn = aws_iam_policy.cognito_admin_get_user.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT PUBLIC API ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_public_api_iam" {
  name = "dappbot-api-public-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_public_api_cloudwatch_logs" {
  role       = aws_iam_role.dappbot_public_api_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# DynamoDB
resource "aws_iam_role_policy_attachment" "dappbot_public_api_dynamodb" {
  role       = aws_iam_role.dappbot_public_api_iam.id
  policy_arn = aws_iam_policy.dynamodb_dapp_table_read_only.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT AUTH API ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_auth_api_iam" {
  name = "dappbot-api-auth-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_auth_api_cloudwatch" {
  role       = aws_iam_role.dappbot_auth_api_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# Cognito
resource "aws_iam_role_policy_attachment" "dappbot_auth_api_cognito" {
  role       = aws_iam_role.dappbot_auth_api_iam.id
  policy_arn = aws_iam_policy.cognito_allow_auth.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT MANAGER IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_manager_iam" {
  name = "dappbot-manager-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_manager_cloudwatch_logs" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# DynamoDB
resource "aws_iam_role_policy_attachment" "dappbot_manager_dynamodb" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.dynamodb_dapp_table_read_write.arn
}

# S3
resource "aws_iam_role_policy_attachment" "dappbot_manager_s3" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.manage_s3_dappseeds_and_buckets.arn
}

# Cloudfront
resource "aws_iam_role_policy_attachment" "dappbot_manager_cloudfront" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.cloudfront_manage_distributions.arn
}

# Route53
resource "aws_iam_role_policy_attachment" "dappbot_manager_route53" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.route53_change_records.arn
}

# CodePipeline
resource "aws_iam_role_policy_attachment" "dappbot_manager_codepipeline_management" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.codepipeline_create_delete_pipeline.arn
}

resource "aws_iam_role_policy_attachment" "dappbot_manager_codepipeline_put_results" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.codepipeline_put_job_result.arn
}

# IAM
resource "aws_iam_role_policy_attachment" "dappbot_manager_iam_pass_role" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.iam_pass_role_to_codepipeline.arn
}

# Cognito
resource "aws_iam_role_policy_attachment" "dappbot_manager_cognito" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.cognito_admin_get_user.arn
}

# SQS
resource "aws_iam_role_policy_attachment" "dappbot_manager_sqs" {
  role       = aws_iam_role.dappbot_manager_iam.id
  policy_arn = aws_iam_policy.sqs_consume_message_dappbot.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT DEAD LETTER HANDLER IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_deadletter_iam" {
  name = "dappbot-deadletter-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_deadletter_cloudwatch" {
  role       = aws_iam_role.dappbot_deadletter_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# SQS
resource "aws_iam_role_policy_attachment" "dappbot_deadletter_sqs" {
  role       = aws_iam_role.dappbot_deadletter_iam.id
  policy_arn = aws_iam_policy.sqs_consume_message_dappbot.arn
}

# DynamoDB
resource "aws_iam_role_policy_attachment" "dappbot_deadletter_dynamodb" {
  role       = aws_iam_role.dappbot_deadletter_iam.id
  policy_arn = aws_iam_policy.dynamodb_dapp_table_read_write.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# DAPPBOT EVENT LISTENER IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_event_listener_iam" {
  name = "dappbot-event-listener-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_cloudwatch" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# Codepipeline
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_codepipeline_management" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.codepipeline_create_delete_pipeline.arn
}

resource "aws_iam_role_policy_attachment" "dappbot_event_listener_codepipeline_put_result" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.codepipeline_put_job_result.arn
}

# SQS
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_sqs" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.sqs_send_message_dappbot.arn
}

# DynamoDB Dapp Table
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_dynamodb_dapps" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.dynamodb_dapp_table_read_write.arn
}

# DynamoDB Lapsed Users Table
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_dynamodb_lapsed_users" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.dynamodb_lapsed_user_table_read_write.arn
}

# Cognito
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_cognito_get_user" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.cognito_admin_get_user.arn
}

resource "aws_iam_role_policy_attachment" "dappbot_event_listener_cognito_update_user_attributes" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.cognito_update_user_attributes.arn
}

# Cloudfront
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_cloudfront" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.cloudfront_manage_existing_distributions.arn
}

# S3
resource "aws_iam_role_policy_attachment" "dappbot_event_listener_s3" {
  role       = aws_iam_role.dappbot_event_listener_iam.id
  policy_arn = aws_iam_policy.s3_modify_artifacts.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# STRIPE PAYMENT GATEWAY IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "stripe_payment_gateway_lambda_iam" {
  name = "stripe-payment-gateway-lambda-iam-${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "stripe_payment_gateway_cloudwatch_logs" {
  role       = aws_iam_role.stripe_payment_gateway_lambda_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# Cognito
resource "aws_iam_role_policy_attachment" "stripe_payment_gateway_cognito" {
  role       = aws_iam_role.stripe_payment_gateway_lambda_iam.id
  policy_arn = aws_iam_policy.cognito_manage_users.arn
}

# SNS
resource "aws_iam_role_policy_attachment" "stripe_payment_gateway_sns" {
  role       = aws_iam_role.stripe_payment_gateway_lambda_iam.id
  policy_arn = aws_iam_policy.sns_publish_payment_events.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "dappbot_codepipeline_iam" {
  name = "dappbot-codepipeline-role-${var.subdomain}"

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


  tags = local.default_tags
}

# Cloudwatch (Logs)
resource "aws_iam_role_policy_attachment" "dappbot_codepipeline_cloudwatch_logs" {
  role       = aws_iam_role.dappbot_codepipeline_iam.id
  policy_arn = aws_iam_policy.lambda_allow_write_cloudwatch_logs.arn
}

# Lambda (Invoke)
resource "aws_iam_role_policy_attachment" "dappbot_codepipeline_invoke" {
  role       = aws_iam_role.dappbot_codepipeline_iam.id
  policy_arn = aws_iam_policy.lambda_invoke.arn
}

# S3
resource "aws_iam_role_policy_attachment" "dappbot_codepipeline_s3" {
  role       = aws_iam_role.dappbot_codepipeline_iam.id
  policy_arn = aws_iam_policy.s3_full_access_managed_buckets.arn
}

# Codebuild
resource "aws_iam_role_policy_attachment" "dappbot_codepipeline_codebuild" {
  role       = aws_iam_role.dappbot_codepipeline_iam.id
  policy_arn = aws_iam_policy.codebuild_build_part.arn
}

# ECR
resource "aws_iam_role_policy_attachment" "dappbot_codepipeline_ecr" {
  role       = aws_iam_role.dappbot_codepipeline_iam.id
  policy_arn = aws_iam_policy.ecr_read_only.arn
}