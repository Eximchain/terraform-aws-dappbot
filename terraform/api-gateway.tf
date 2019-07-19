# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "dapp_api" {
  name        = "dappbot-${var.subdomain}"
  description = "Proxy to handle requests to the Dappbot & Dapphub API"
}

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
    aws_api_gateway_method.dappbot_auth_proxy_any
  ]

  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  stage_name  = "v1"
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/private/` DAPPBOT API
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_api_gateway_resource" "dappbot_private" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_rest_api.dapp_api.root_resource_id
  path_part   = "private"
}

resource "aws_api_gateway_method" "dappbot_private_get" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = "GET"

  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_auth.id
}

resource "aws_api_gateway_method_response" "dappbot_private_get" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = aws_api_gateway_method.dappbot_private_get.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  depends_on = [aws_api_gateway_method.dappbot_private_get]
}

resource "aws_api_gateway_integration" "dappbot_private_get" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = aws_api_gateway_method.dappbot_private_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dappbot_lambda_uri

  depends_on = [
    aws_api_gateway_method.dappbot_private_get,
    aws_lambda_function.dappbot_api_lambda
  ]
}

resource "aws_api_gateway_authorizer" "api_auth" {
  name          = "dappbot-auth-${var.subdomain}"
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  provider_arns = [aws_cognito_user_pool.registered_users.arn]

  identity_source = "method.request.header.Authorization"
  type            = "COGNITO_USER_POOLS"
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/private/{proxy}` DAPPBOT API
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_api_gateway_resource" "dappbot_private_proxy" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_resource.dappbot_private.id
  path_part   = "{proxy+}"
}

TODO: Placeholder to jump back and find auth config

resource "aws_api_gateway_method" "dappbot_private_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = "ANY"

  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_auth.id

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_method_response" "dappbot_private_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = aws_api_gateway_method.dappbot_private_proxy_any.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  depends_on = [aws_api_gateway_method.dappbot_private_proxy_any]
}

resource "aws_api_gateway_integration" "dappbot_private_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = aws_api_gateway_method.dappbot_private_proxy_any.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dappbot_lambda_uri

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  depends_on = [
    aws_api_gateway_method.dappbot_private_proxy_any,
    aws_lambda_function.dappbot_api_lambda
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/private/` CORS PREFLIGHT HANDLING
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_api_gateway_method" "dappbot_private_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = "OPTIONS"

  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "dappbot_private_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = aws_api_gateway_method.dappbot_private_cors.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.dappbot_private_cors
  ]
}

resource "aws_api_gateway_integration" "dappbot_private_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = aws_api_gateway_method.dappbot_private_cors.http_method

  type = "MOCK"

  request_templates = { 
    "application/json" = "{ \"statusCode\": 200   }"
  }

  depends_on = [
    aws_api_gateway_method.dappbot_private_cors
  ]
}

resource "aws_api_gateway_integration_response" "dappbot_private_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private.id
  http_method = aws_api_gateway_method.dappbot_private_cors.http_method
  status_code = aws_api_gateway_method_response.dappbot_private_cors.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.dappbot_private_cors,
    aws_api_gateway_method.dappbot_private_cors
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/private/{proxy}` CORS PREFLIGHT HANDLING
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_api_gateway_method" "dappbot_private_proxy_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = "OPTIONS"

  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "dappbot_private_proxy_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = aws_api_gateway_method.dappbot_private_proxy_cors.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [aws_api_gateway_method.dappbot_private_proxy_cors]
}

resource "aws_api_gateway_integration" "dappbot_private_proxy_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = aws_api_gateway_method.dappbot_private_proxy_cors.http_method

  type = "MOCK"

  request_templates = { 
    "application/json" = "{ \"statusCode\": 200 }"
  }

  depends_on = [aws_api_gateway_method.dappbot_private_proxy_cors]
}

resource "aws_api_gateway_integration_response" "dappbot_private_proxy_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_private_proxy.id
  http_method = aws_api_gateway_method.dappbot_private_proxy_cors.http_method
  status_code = aws_api_gateway_method_response.dappbot_private_proxy_cors.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.dappbot_private_proxy_cors, 
    aws_api_gateway_method_response.dappbot_private_proxy_cors
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/public/{proxy}` DAPPBOT PUBLIC API
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "dappbot_public" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_rest_api.dapp_api.root_resource_id
  path_part   = "public"
}

resource "aws_api_gateway_resource" "dappbot_public_proxy" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_resource.dappbot_public.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "dappbot_public_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_public_proxy.id
  http_method = "ANY"

  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dappbot_public_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_public_proxy.id
  http_method = aws_api_gateway_method.dappbot_public_proxy_any.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dapphub_lambda_uri

  depends_on = [
    aws_api_gateway_method.dappbot_public_proxy_any
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/auth/{proxy}` DAPPBOT AUTH API
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "dappbot_auth" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_rest_api.dapp_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "dappbot_auth_proxy" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_resource.dappbot_auth.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "dappbot_auth_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_auth_proxy.id
  http_method = "ANY"

  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "dappbot_auth_proxy_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.dappbot_auth_proxy.id
  http_method = aws_api_gateway_method.dappbot_auth_proxy_any.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.dappbot_auth_lambda_uri

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/payment` PAYMENT GATEWAY API ROOT RESOURCE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "payment" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_rest_api.dapp_api.root_resource_id
  path_part   = "payment"
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `ANY /payment/stripe/` STRIPE SIGNUP GATEWAY API
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "payment_stripe" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  parent_id   = aws_api_gateway_resource.payment.id
  path_part   = "stripe"
}

resource "aws_api_gateway_method" "payment_stripe_any" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  resource_id   = aws_api_gateway_resource.payment_stripe.id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.api_auth.id

  request_parameters = {
    "method.request.header.Stripe-Signature" = true
  }
}

resource "aws_api_gateway_method_response" "payment_stripe_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.payment_stripe.id
  http_method = aws_api_gateway_method.payment_stripe_any.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  depends_on = [aws_api_gateway_method.payment_stripe_any]
}

resource "aws_api_gateway_integration" "payment_stripe_any" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.payment_stripe.id
  http_method = aws_api_gateway_method.payment_stripe_any.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = local.stripe_management_gateway_lambda_uri

  request_parameters = {
    "integration.request.header.Stripe-Signature" = "method.request.header.Stripe-Signature"
  }

  depends_on = [
    aws_api_gateway_method.payment_stripe_any,
    aws_lambda_function.stripe_management_gateway_lambda
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `/payment/stripe/` CORS PREFLIGHT HANDLING
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_api_gateway_method" "payment_stripe_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.payment_stripe.id
  http_method = "OPTIONS"

  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "payment_stripe_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.payment_stripe.id
  http_method = aws_api_gateway_method.payment_stripe_cors.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.payment_stripe_cors
  ]
}

resource "aws_api_gateway_integration" "payment_stripe_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.payment_stripe.id
  http_method = aws_api_gateway_method.payment_stripe_cors.http_method

  type = "MOCK"

  request_templates = { 
    "application/json" = "{ \"statusCode\": 200   }"
  }

  depends_on = [
    aws_api_gateway_method.payment_stripe_cors
  ]
}

resource "aws_api_gateway_integration_response" "payment_stripe_cors" {
  rest_api_id = aws_api_gateway_rest_api.dapp_api.id
  resource_id = aws_api_gateway_resource.payment_stripe.id
  http_method = aws_api_gateway_method.payment_stripe_cors.http_method
  status_code = aws_api_gateway_method_response.payment_stripe_cors.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.payment_stripe_cors,
    aws_api_gateway_method.payment_stripe_cors
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `POST /payment/stripe/` STRIPE MANAGEMENT GATEWAY API
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY: `ANY /payment/stripe/webhook` STRIPE WEBHOOK GATEWAY API
# ---------------------------------------------------------------------------------------------------------------------


# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY RESPONSES
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_gateway_response" "access_denied" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "ACCESS_DENIED"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "api_configuration_error" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "API_CONFIGURATION_ERROR"
  status_code   = "500"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "authorizer_configuration_error" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "AUTHORIZER_CONFIGURATION_ERROR"
  status_code   = "500"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "authorizer_failure" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "AUTHORIZER_FAILURE"
  status_code   = "500"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "bad_request_parameters" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "BAD_REQUEST_PARAMETERS"
  status_code   = "400"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "bad_request_body" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "BAD_REQUEST_BODY"
  status_code   = "400"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "expired_token" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "EXPIRED_TOKEN"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "integration_failure" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INTEGRATION_FAILURE"
  status_code   = "504"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "integration_timeout" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INTEGRATION_TIMEOUT"
  status_code   = "504"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "invalid_api_key" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INVALID_API_KEY"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "invalid_signature" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "INVALID_SIGNATURE"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "missing_authentication_token" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "MISSING_AUTHENTICATION_TOKEN"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "quota_exceeded" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "QUOTA_EXCEEDED"
  status_code   = "429"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "request_too_large" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "REQUEST_TOO_LARGE"
  status_code   = "413"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "resource_not_found" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "RESOURCE_NOT_FOUND"
  status_code   = "404"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "throttled" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "THROTTLED"
  status_code   = "429"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "UNAUTHORIZED"
  status_code   = "401"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "unsupported_media_type" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "UNSUPPORTED_MEDIA_TYPE"
  status_code   = "415"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

resource "aws_api_gateway_gateway_response" "waf_filtered" {
  rest_api_id   = aws_api_gateway_rest_api.dapp_api.id
  response_type = "WAF_FILTERED"
  status_code   = "403"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "gatewayresponse.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY DOMAIN
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_domain_name" "domain" {
  certificate_arn = local.api_cert_arn
  domain_name     = local.api_domain

  depends_on = [aws_acm_certificate_validation.api_cert]
}

resource "aws_api_gateway_base_path_mapping" "base_path_mapping" {
  api_id = aws_api_gateway_rest_api.dapp_api.id

  domain_name = aws_api_gateway_domain_name.domain.domain_name
}

resource "aws_route53_record" "example" {
  name    = aws_api_gateway_domain_name.domain.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.domain.cloudfront_zone_id
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# API GATEWAY LAMBDA INVOCATION PERMISSIONS
# ---------------------------------------------------------------------------------------------------------------------
# Private API
resource "aws_lambda_permission" "api_gateway_invoke_dappbot_private_api_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# Public API
resource "aws_lambda_permission" "api_gateway_invoke_dapphub_public_api_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dapphub_view_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# Auth API
resource "aws_lambda_permission" "api_gateway_invoke_dappbot_auth_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dappbot_auth_api_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# Stripe Signup Gateway API
resource "aws_lambda_permission" "api_gateway_invoke_stripe_signup_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stripe_signup_gateway_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# Stripe Management Gateway API
resource "aws_lambda_permission" "api_gateway_invoke_stripe_management_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stripe_management_gateway_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}

# Stripe Webhook Gateway API
resource "aws_lambda_permission" "api_gateway_invoke_stripe_webhook_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stripe_webhook_gateway_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = local.api_gateway_source_arn
}