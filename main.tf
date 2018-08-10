################################################################################
# Config
################################################################################

terraform {
  required_version = ">= 0.11"
  backend "s3" {}
}

provider "aws" {
  version = ">= 1.20"
  region = "${var.region}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

################################################################################
# IAM
################################################################################

resource "aws_iam_role" "iam_lambda" {
  name = "${var.environment_prefix}_webhooks_ci_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "iam_lambda_policy" {
    name = "${var.environment_prefix}_webhooks_ci_lambda"
    description = "${var.environment_prefix}_webhooks_ci_lambda"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Effect": "Allow",
    "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
    ],
    "Resource": "arn:aws:logs:*:*:*"
  },
  {
    "Effect": "Allow",
    "Action": [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ],
      "Resource": "*"
    }
  ]
}
EOF
}

################################################################################
# Lambda
################################################################################

resource "aws_iam_role_policy_attachment" "iam_lambda_policy_attach" {
  role = "${aws_iam_role.iam_lambda.name}"
  policy_arn = "${aws_iam_policy.iam_lambda_policy.arn}"
}

resource "aws_lambda_function" "lambda" {
  filename = "webhooks_lambda.zip"
  source_code_hash = "${base64sha256(file("webhooks_lambda.zip"))}"
  function_name = "${var.environment_prefix}_webhooks_ci"
  runtime = "python3.6"
  handler = "main.handler"
  timeout = "${var.lambda_webhook_timeout}"
  role = "${aws_iam_role.iam_lambda.arn}"
  vpc_config       {
      subnet_ids         = ["${var.lambda_webhook_subnets_id}"]
      security_group_ids = ["${var.lambda_webhook_sg_id}"]
  }
}

resource "aws_lambda_permission" "lambda_allow_api_gateway" {
  depends_on = [
    "aws_api_gateway_rest_api.webhooks",
  ]

  function_name = "${aws_lambda_function.lambda.function_name}"
  statement_id = "AllowExecutionFromApiGateway"
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.webhooks.id}/*"
}

################################################################################
# API
################################################################################

resource "aws_api_gateway_rest_api" "webhooks" {
  name = "${var.environment_prefix}_webhooks_ci"
  description = "${var.environment_prefix}_webhooks_ci"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "service" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  parent_id = "${aws_api_gateway_rest_api.webhooks.root_resource_id}"
  path_part = "{service}"
}

resource "aws_api_gateway_resource" "type" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  parent_id = "${aws_api_gateway_resource.service.id}"
  path_part = "{type}"
}

resource "aws_api_gateway_method" "type_get" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "GET"
  authorization = "NONE"
  request_parameters  = {
      "method.request.querystring.remote" = true
  }
}

resource "aws_api_gateway_method_response" "type_get_200" {
  depends_on = [
    "aws_api_gateway_method.type_get",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "${aws_api_gateway_method.type_get.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "type_get_200" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "${aws_api_gateway_method.type_get.http_method}"
  status_code = "${aws_api_gateway_method_response.type_get_200.status_code}"

}

resource "aws_api_gateway_method" "type_post" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "type_post_200" {
  depends_on = [
    "aws_api_gateway_method.type_post",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "${aws_api_gateway_method.type_post.http_method}"
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "type_post_200" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "${aws_api_gateway_method.type_post.http_method}"
  status_code = "${aws_api_gateway_method_response.type_post_200.status_code}"

}

resource "aws_api_gateway_integration" "type_get" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "${aws_api_gateway_method.type_get.http_method}"
  type = "AWS"
  integration_http_method = "POST"
  uri = "${aws_lambda_function.lambda.invoke_arn}"

  request_templates = {
    "application/json" = <<EOF
{
    "service": "custom",
    "type": "$input.params('type')",
    "remotes": [
    ]
}
EOF
  }
}

resource "aws_api_gateway_integration" "type_post" {
  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  resource_id = "${aws_api_gateway_resource.type.id}"
  http_method = "${aws_api_gateway_method.type_post.http_method}"
  type = "AWS"
  integration_http_method = "POST"
  uri = "${aws_lambda_function.lambda.invoke_arn}"
  request_templates = {
    "application/json" = <<EOF
    {
        "service": "$input.params('service')",
        "type": "$input.params('type')",
        "remotes": [
            #if($input.params('service')=='github')
                "$input.path('repository.html_url')",
                "$input.path('repository.ssh_url')"
            #elseif($input.params('service')=='bitbucket')
                #set($ssh_remote = $input.path('repository.links.html.href').replace('https://bitbucket.org/','git@bitbucket.org:'))
                #set($ssh_remote = $ssh_remote.concat('.git'))
                "$ssh_remote",
                "$input.path('repository.links.html.href')"
            #else
                "custom"
            #end
        ]
    }
EOF
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    "aws_api_gateway_integration.type_get",
    "aws_api_gateway_integration.type_post",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  stage_name  = "${var.api_stage}"
}

################################################################################
# Route 53
################################################################################

data "aws_acm_certificate" "webhook" {
  domain = "${var.webhook_acm_certificate}"
}

data "aws_route53_zone" "webhook" {
  name = "${var.webhook_domain}"
}

resource "aws_api_gateway_domain_name" "webhook" {
  domain_name = "${var.webhook_dns}"
  regional_certificate_arn = "${data.aws_acm_certificate.webhook.arn}"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_route53_record" "webhook" {
  zone_id = "${data.aws_route53_zone.webhook.zone_id}"
  name = "${var.webhook_dns}"
  type = "A"

  alias {
    name = "${aws_api_gateway_domain_name.webhook.regional_domain_name}"
    zone_id = "${aws_api_gateway_domain_name.webhook.regional_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_api_gateway_base_path_mapping" "webhook" {
  api_id = "${aws_api_gateway_rest_api.webhooks.id}"
  stage_name = "${aws_api_gateway_deployment.deployment.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.webhook.domain_name}"
  base_path = "${var.api_stage}"
}
