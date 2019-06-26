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

  tags = "${local.default_tags}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CODEPIPELINE IAM ACCESS
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "codepipeline" {
  name = "allow-s3-dappbot-codepipeline-${var.subdomain}"

  policy = "${data.aws_iam_policy_document.codepipeline.json}"
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = "${aws_iam_role.dappbot_codepipeline_iam.id}"
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
    sid = "CodeBuildStart"

    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]

    resources = ["*"]
  }

  statement {
    sid = "LambdaInvoke"

    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
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