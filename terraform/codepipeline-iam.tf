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
    sid = "Lambda"

    effect = "Allow"

    actions = [
      "lambda:InvokeFunction"
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