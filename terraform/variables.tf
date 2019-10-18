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
  default     = "dappbot-api"
}

variable "dapphub_subdomain" {
  description = "subdomain on which to host the Dapphub. The Dapphub DNS will be {dapphub_subdomain}.{root_domain}"
  default     = "dapphub"
}

variable "dapphub_branch" {
  description = "branch of the 'dapphub-spa' repository to deploy to Dapphub"
  default     = "master"
}

variable "dappbot_manager_subdomain" {
  description = "subdomain on which to host the DappBot Manager. The DappBot Manager DNS will be {dappbot_manager_subdomain}.{root_domain}"
  default     = "dappbot-manager"
}

variable "dappbot_manager_branch" {
  description = "branch of the 'dappbot-management-spa' repository to deploy to DappBot Manager"
  default     = "master"
}

variable "lambda_default_branch" {
  description = "Branch to use for Lambda repositories if no override is specified"
  default     = "master"
}

variable "dappbot_api_lambda_branch_override" {
  description = "An override for the dappbot-api-lambda repository branch. Will use Lambda default if left blank."
  default     = ""
}

variable "dappbot_manager_lambda_branch_override" {
  description = "An override for the dappbot-manager-lambda repository branch. Will use Lambda default if left blank."
  default     = ""
}

variable "dappbot_event_listener_lambda_branch_override" {
  description = "An override for the dappbot-event-listener-lambda repository branch. Will use Lambda default if left blank."
  default     = ""
}

variable "payment_gateway_stripe_lambda_branch_override" {
  description = "An override for the payment-gateway-stripe-lambda repository branch. Will use Lambda default if left blank."
  default     = ""
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

variable "payment_lapsed_grace_period_hours" {
  description = "Number of hours to wait after a LAPSED payment before deleting dapps"
  default     = 72
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

variable "stripe_api_key" {
  description = "Secret key to make server-side calls to the Stripe API. Must be set for Stripe interactions to succeed."
  default     = ""
}

variable "stripe_webhook_secret" {
  description = "Stripe secret used to decrypt webhook payloads.  One per webhook."
  default     = ""
}

variable "stripe_public_key" {
  description = "Publishable secret key so clients can tokenize card information.  Must be set for client-side Stripe interactions to succeed."
  default     = ""
}

variable "eximchain_accounts_only" {
  description = "If true, only `@eximchain.com` emails will be permitted to sign up for accounts."
  default     = true
}

variable "segment_nodejs_write_key" {
  description = "Publishable key to send analytics calls to Segment.io from Lambdas.  Must be set in order to get usage analytics."
  default     = ""
}

variable "segment_browser_write_key" {
  description = "Publishable key to send analytics calls to Segment.io from the browser.  Must be set in order to get usage analytics."
  default     = ""
}