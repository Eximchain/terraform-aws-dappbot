# --------------------------------------------------------
# REQUIRED NPM VARIABLES
# --------------------------------------------------------

variable "npm_user" {
    description = "Username for the NPM account which is a member of the eximchain organization. Required, @eximchain/dappsmith is private."
}

variable "npm_pass" {
    description = "Password for the NPM account which is a member of the eximchain organization. Required, @eximchain/dappsmith is private."
}

variable "npm_email" {
    description = "Email for the NPM account which is a member of the eximchain organization. Required, @eximchain/dappsmith is private."
}

variable "codebuild_image" {
    description = "Name of the Docker image kept in AWS ECR.  No leading /, just org/repo:tag"
}

variable "aws_account_id" {
    description = "12-digit AWS Account ID.  Required for building ECR URL."
}

# --------------------------------------------------------
# OPTIONAL AWS & DOMAIN VARIABLES
# --------------------------------------------------------

variable "aws_region" {
    description = "AWS Region to use"
    default     = "us-east-1"
}

variable "root_domain" {
    description = "Root domain on Route 53 on which to host the API"
    default     = "eximchain-dev.com"
}

variable "subdomain" {
    description = "subdomain on which to host the API. The API DNS will be {subdomain}.{root_domain}"
    default     = "api-test"
}

variable "create_wildcard_cert" {
    description = "Create a new wildcard certificate.  Requires 30 minutes or more for validation.  If false, expects a validated cert to already exist for '*.subdomain.root_domain'."
    default     = false
}