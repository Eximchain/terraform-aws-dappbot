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
  description = "Name of the Docker image kept in AWS ECR.  No leading /, just org/repo:tag.  Expects to have dappsmith and create-react-app installed."
}

# --------------------------------------------------------
# OPTIONAL AWS, DOMAIN, & SENDGRID VARIABLES
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

variable "dapphub_subdomain" {
  description = "subdomain on which to host the Dapphub. The Dapphub DNS will be {dapphub_subdomain}.{root_domain}"
  default     = "hub-test"
}

variable "dapphub_branch" {
  description = "branch of the 'dapphub-spa' repository to deploy to Dapphub"
  default     = "master"
}

variable "dappbot_manager_subdomain" {
  description = "subdomain on which to host the DappBot Manager. The DappBot Manager DNS will be {dappbot_manager_subdomain}.{root_domain}"
  default     = "dappbot-manager-test"
}

variable "dappbot_manager_branch" {
  description = "branch of the 'dappbot-management-spa' repository to deploy to DappBot Manager"
  default     = "master"
}

variable "create_wildcard_cert" {
  description = "Create a new wildcard subdomain certificate.  Requires 30 minutes or more for validation.  If false, expects a validated cert to already exist for '*.subdomain.root_domain'."
  default     = false
}

variable "existing_cert_domain" {
  description = "The Domain of an existing ACM certificate that is valid for all domains the api or any other single-domain resources. Will provision one if not provided."
  default     = ""
}

variable "sendgrid_key" {
  description = "Sendgrid API key to be used for sending users confirmation emails."
  default     = ""
}

variable "service_github_token" {
  description = "The GitHub token to use to commit source for Enterprise"
  default     = ""
}

variable "payment_event_publishers" {
  description = "A list of ARNs that should be allowed to publish payment events"
  default     = []
  type        = list(string)
}

# If singular, it's 1 hour, 1 minute, 1 week, 1 day, etc.
variable "cleanup_interval" {
  description = <<DESCRIPTION
Schedule expression for cleanup event, see https://docs.aws.amazon.com/lambda/latest/dg/tutorial-scheduled-events-schedule-expressions.html for examples.
cron(45 08 ? * WED *) will trigger every WED at 8 45 am GMT
cron(05 13 ? * MON *) will trigger every MON at 1 05 pm GMT
rate(3 mins) will trigger every 3 minutes
rate(7 hours) will trigger every 7 hours
DESCRIPTION


  default = "rate(12 hours)"
}