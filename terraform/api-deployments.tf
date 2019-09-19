# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY INITIAL DEPLOYMENT
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "dapp_api_deploy_v1" {
  depends_on = [
    aws_api_gateway_integration.dappbot_public_proxy_any,
    aws_api_gateway_method.dappbot_public_proxy_any,

    aws_api_gateway_integration.dappbot_private_proxy_any,
    aws_api_gateway_method.dappbot_private_proxy_any,

    aws_api_gateway_integration.dappbot_private_get,
    aws_api_gateway_method.dappbot_private_get,

    aws_api_gateway_integration.dappbot_private_proxy_cors,
    aws_api_gateway_method.dappbot_private_proxy_cors,

    aws_api_gateway_integration.dappbot_private_cors,
    aws_api_gateway_method.dappbot_private_cors,

    aws_api_gateway_integration.dappbot_auth_proxy_any,
    aws_api_gateway_method.dappbot_auth_proxy_any,

    aws_api_gateway_integration.payment_stripe_any,
    aws_api_gateway_method.payment_stripe_any,

    aws_api_gateway_integration.payment_stripe_post,
    aws_api_gateway_method.payment_stripe_post,

    aws_api_gateway_integration.payment_stripe_cors,
    aws_api_gateway_method.payment_stripe_cors,

    aws_api_gateway_integration.payment_stripe_webhook_any,
    aws_api_gateway_method.payment_stripe_webhook_any
  ]

  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  stage_name  = "v1"
}

// v1 stage second deployment
// Add configure-mfa endpoint
resource "aws_api_gateway_deployment" "dapp_api_deploy_v1_configure_mfa" {
  depends_on = [
    aws_api_gateway_integration.dappbot_auth_configure_mfa_any,
    aws_api_gateway_method.dappbot_auth_configure_mfa_any,

    aws_api_gateway_integration.dappbot_auth_configure_mfa_cors,
    aws_api_gateway_method.dappbot_auth_configure_mfa_cors,
  ]

  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  stage_name  = "v1"
}