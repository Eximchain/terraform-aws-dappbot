# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH WRITE LAMBDA LOGS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "lambda_allow_write_cloudwatch_logs" {
  name = "lambda-allow-write-logs-${var.subdomain}"

  policy = data.aws_iam_policy_document.lambda_allow_write_cloudwatch_logs.json
}

data "aws_iam_policy_document" "lambda_allow_write_cloudwatch_logs" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ASSUME ROLE LAMBDA POLICY DOCUMENT
# ---------------------------------------------------------------------------------------------------------------------
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
# DYNAMODB DAPP TABLE READ/WRITE ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dynamodb_dapp_table_read_write" {
  name = "dynamodb-dapp-table-read-write-${var.subdomain}"

  policy = data.aws_iam_policy_document.dynamodb_dapp_table_read_write.json
}

data "aws_iam_policy_document" "dynamodb_dapp_table_read_write" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable",
    ]

    resources = [aws_dynamodb_table.dapp_table.arn]
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
      "dynamodb:Query",
    ]

    resources = [
      aws_dynamodb_table.dapp_table.arn,
      "${aws_dynamodb_table.dapp_table.arn}/*",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMODB DAPP TABLE READ ONLY ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dynamodb_dapp_table_read_only" {
  name = "dynamodb-dapp-table-read-only-${var.subdomain}"

  policy = data.aws_iam_policy_document.dynamodb_dapp_table_read_only.json
}

data "aws_iam_policy_document" "dynamodb_dapp_table_read_only" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable",
    ]

    resources = [aws_dynamodb_table.dapp_table.arn]
  }

  statement {
    sid = "2"

    effect = "Allow"

    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]

    resources = [
      aws_dynamodb_table.dapp_table.arn,
      "${aws_dynamodb_table.dapp_table.arn}/*",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DYNAMODB LAPSED USER TABLE READ/WRITE ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "dynamodb_lapsed_user_table_read_write" {
  name = "dynamodb-lapsed-users-read-write-lambda-${var.subdomain}"

  policy = data.aws_iam_policy_document.dappbot_event_listener_allow_dynamodb_lapsed_users.json
}

data "aws_iam_policy_document" "dappbot_event_listener_allow_dynamodb_lapsed_users" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "dynamodb:DescribeTable",
    ]
    resources = [aws_dynamodb_table.lapsed_users_table.arn]
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
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.lapsed_users_table.arn,
      "${aws_dynamodb_table.lapsed_users_table.arn}/*",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SQS SEND MESSAGES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "sqs_send_message_dappbot" {
  name = "sqs-send-message-dappbot-${var.subdomain}"

  policy = data.aws_iam_policy_document.sqs_send_message_dappbot.json
}

data "aws_iam_policy_document" "sqs_send_message_dappbot" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "sqs:SendMessage",
    ]

    resources = [aws_sqs_queue.dappbot.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SQS CONSUME MESSAGES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "sqs_consume_message_dappbot" {
  name = "sqs-consume-message-dappbot-${var.subdomain}"

  policy = data.aws_iam_policy_document.sqs_consume_message_dappbot.json
}

data "aws_iam_policy_document" "sqs_consume_message_dappbot" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [
      aws_sqs_queue.dappbot.arn,
      aws_sqs_queue.dappbot_deadletter.arn,
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# COGNITO ALLOW ADMIN GET USER
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "cognito_admin_get_user" {
  name = "cognito-admin-get-user-${var.subdomain}"

  policy = data.aws_iam_policy_document.cognito_admin_get_user.json
}

data "aws_iam_policy_document" "cognito_admin_get_user" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cognito-idp:AdminGetUser",
    ]
    resources = [aws_cognito_user_pool.registered_users.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# COGNITO ALLOW UPDATE USER ATTRIBUTES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "cognito_update_user_attributes" {
  name = "cognito-allow-update-user-attrs-${var.subdomain}"

  policy = data.aws_iam_policy_document.cognito_update_user_attributes.json
}

data "aws_iam_policy_document" "cognito_update_user_attributes" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cognito-idp:AdminUpdateUserAttributes",
    ]
    resources = [aws_cognito_user_pool.registered_users.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# COGNITO ALLOW AUTH
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "cognito_allow_auth" {
  name = "cognito-allow-auth-${var.subdomain}"

  policy = data.aws_iam_policy_document.cognito_allow_auth.json
}

data "aws_iam_policy_document" "cognito_allow_auth" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cognito-idp:AdminInitiateAuth",
      "cognito-idp:AdminConfirmSignUp",
      "cognito-idp:AdminResetUserPassword",
      "cognito-idp:AdminRespondToAuthChallenge",
      "cognito-idp:AssociateSoftwareToken",
      "cognito-idp:GetUser",
      "cognito-idp:VerifySoftwareToken"
    ]

    resources = [aws_cognito_user_pool.registered_users.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# COGNITO MANAGE USERS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "cognito_manage_users" {
  name = "cognito-stripe-payment-gateway-${var.subdomain}"

  policy     = data.aws_iam_policy_document.cognito_manage_users.json
}

data "aws_iam_policy_document" "cognito_manage_users" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminDeleteUser",
      "cognito-idp:AdminGetUser",
      "cognito-idp:SignUp",
      "cognito-idp:VerifyUserAttribute",
    ]

    resources = [aws_cognito_user_pool.registered_users.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 MANAGE DAPPSEEDS AND DAPP BUCKETS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "manage_s3_dappseeds_and_buckets" {
  name = "s3-manage-dappseeds-${var.subdomain}"

  policy = data.aws_iam_policy_document.manage_s3_dappseeds_and_buckets.json
}

data "aws_iam_policy_document" "manage_s3_dappseeds_and_buckets" {
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
      "s3:PutObjectAcl",
    ]
    resources = [
      local.s3_bucket_arn_pattern,
      aws_s3_bucket.dappseed_bucket.arn,
    ]
  }

  statement {
    sid = "2"

    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListObjects",
    ]
    resources = [
      "${local.s3_bucket_arn_pattern}/*",
      "${aws_s3_bucket.dappseed_bucket.arn}/*",
      aws_s3_bucket.artifact_bucket.arn,
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 MODIFY ARTIFACTS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "s3_modify_artifacts" {
  name = "s3-modify-artifacts-${var.subdomain}"

  policy = data.aws_iam_policy_document.s3_modify_artifacts.json
}

data "aws_iam_policy_document" "s3_modify_artifacts" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "s3:GetObjectAcl",
      "s3:PutObjectAcl",
    ]
    
    resources = [
      local.s3_bucket_arn_pattern,
    ]
  }

  statement {
    sid = "2"

    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]

    resources = [
      "${local.s3_bucket_arn_pattern}/*",
      aws_s3_bucket.artifact_bucket.arn,
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDFRONT MANAGE DISTRIBUTIONS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "cloudfront_manage_distributions" {
  name = "cloudfront-manage-distributions-${var.subdomain}"

  policy = data.aws_iam_policy_document.cloudfront_manage_distributions.json
}

data "aws_iam_policy_document" "cloudfront_manage_distributions" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:TagResource",
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:ListDistributions",
      "cloudfront:ListTagsForResource",
      "cloudfront:CreateInvalidation",
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDFRONT MANAGE EXISTING DISTRIBUTIONS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "cloudfront_manage_existing_distributions" {
  name = "cloudfront-manage-existing-distributions-${var.subdomain}"

  policy = data.aws_iam_policy_document.cloudfront_manage_existing_distributions.json
}

data "aws_iam_policy_document" "cloudfront_manage_existing_distributions" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:ListDistributions",
      "cloudfront:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ROUTE53 CHANGE RECORDS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "route53_change_records" {
  name = "route53-change-records-${var.subdomain}"

  policy = data.aws_iam_policy_document.route53_change_records.json
}

data "aws_iam_policy_document" "route53_change_records" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE CREATE/DELETE PIPELINE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codepipeline_create_delete_pipeline" {
  name = "codepipeline-create-delete-pipeline-${var.subdomain}"

  policy = data.aws_iam_policy_document.codepipeline_create_delete_pipeline.json
}

data "aws_iam_policy_document" "codepipeline_create_delete_pipeline" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "codepipeline:CreatePipeline",
      "codepipeline:DeletePipeline",
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE PUT JOB RESULT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codepipeline_put_job_result" {
  name = "codepipeline-put-job-result-${var.subdomain}"

  policy = data.aws_iam_policy_document.codepipeline_put_job_result.json
}

data "aws_iam_policy_document" "codepipeline_put_job_result" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutJobFailureResult",
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM PASS ROLE TO CODEPIPELINE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "iam_pass_role_to_codepipeline" {
  name = "iam-pass-role-codepipeline-${var.subdomain}"

  policy = data.aws_iam_policy_document.iam_pass_role_to_codepipeline.json
}

data "aws_iam_policy_document" "iam_pass_role_to_codepipeline" {
  version = "2012-10-17"

  statement {
    sid = "1"

    effect = "Allow"

    actions = [
      "iam:PassRole",
    ]
    resources = [aws_iam_role.dappbot_codepipeline_iam.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# POLICY FOR CODEPIPELINE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codepipeline_policy" {
  name = "dappbot-codepipeline-policy-${var.subdomain}"

  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

data "aws_iam_policy_document" "codepipeline_policy" {
  version = "2012-10-17"

  statement {
    sid = "S3Access"

    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      local.s3_bucket_arn_pattern,
      "${local.s3_bucket_arn_pattern}/*",
      aws_s3_bucket.dappseed_bucket.arn,
      "${aws_s3_bucket.dappseed_bucket.arn}/*",
      aws_s3_bucket.artifact_bucket.arn,
      "${aws_s3_bucket.artifact_bucket.arn}/*",
    ]
  }

  statement {
    sid = "CodeBuildStart"

    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }

  statement {
    sid = "LambdaInvoke"

    effect = "Allow"

    actions = [
      "lambda:InvokeFunction",
    ]

    // A known issue with the Lambda IAM permissions system makes it impossible
    // to grant more granular permissions.  lambda:InvokeFunction cannot be called
    // on specific functions, and lambda:Invoke is not recognized as a valid policy.
    // Given that only our Lambda can create the CodePipeline which has this role,
    // I think it ought to be fine.  Frustrating, though.  - John
    //
    // https://stackoverflow.com/q/48031334/2128308
    resources = ["*"]
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
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# S3 FULL ACCESS MANAGED BUCKETS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "s3_full_access_managed_buckets" {
  name = "s3-full-access-${var.subdomain}"

  policy = data.aws_iam_policy_document.s3_full_access_managed_buckets.json
}

data "aws_iam_policy_document" "s3_full_access_managed_buckets" {
  version = "2012-10-17"

  statement {
    sid = "S3Access"

    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      local.s3_bucket_arn_pattern,
      "${local.s3_bucket_arn_pattern}/*",
      aws_s3_bucket.dappseed_bucket.arn,
      "${aws_s3_bucket.dappseed_bucket.arn}/*",
      aws_s3_bucket.artifact_bucket.arn,
      "${aws_s3_bucket.artifact_bucket.arn}/*",
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SNS PUBLISH PAYMENT EVENTS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "sns_publish_payment_events" {
  name = "sns-publish-payment-events-${var.subdomain}"

  policy = data.aws_iam_policy_document.sns_publish_payment_events.json
}

data "aws_iam_policy_document" "sns_publish_payment_events" {
  statement {
    sid = "1"

    effect  = "Allow"

    actions   = ["sns:Publish"]

    resources = [aws_sns_topic.payment_events.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEBUILD BUILD START
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codebuild_build_part" {
  name = "codebuild-build-part-${var.subdomain}"

  policy = data.aws_iam_policy_document.codebuild_build_part.json
}

data "aws_iam_policy_document" "codebuild_build_part" {
  version = "2012-10-17"

  statement {
    sid = "CodeBuildStart"

    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA INVOKE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "lambda_invoke" {
  name = "lambda-invoke-${var.subdomain}"

  policy = data.aws_iam_policy_document.lambda_invoke.json
}

data "aws_iam_policy_document" "lambda_invoke" {
  version = "2012-10-17"

  statement {
    sid = "LambdaInvoke"

    effect = "Allow"

    actions = [
      "lambda:InvokeFunction",
    ]

    // A known issue with the Lambda IAM permissions system makes it impossible
    // to grant more granular permissions.  lambda:InvokeFunction cannot be called
    // on specific functions, and lambda:Invoke is not recognized as a valid policy.
    // Given that only our Lambda can create the CodePipeline which has this role,
    // I think it ought to be fine.  Frustrating, though.  - John
    //
    // https://stackoverflow.com/q/48031334/2128308
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ECR READ ONLY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "ecr_read_only" {
  name = "ecr-read-only-${var.subdomain}"

  policy = data.aws_iam_policy_document.ecr_read_only.json
}

data "aws_iam_policy_document" "ecr_read_only" {
  version = "2012-10-17"

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
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }
}