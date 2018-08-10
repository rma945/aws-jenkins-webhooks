variable "region" {
    default = "us-west-1"
}

variable "environment_prefix" {
    type    = "string"
    default = "company"
}

variable "lambda_webhook_subnets_id" {
    type    = "string"
    default = "subnet-0000000"
}

variable "lambda_webhook_sg_id" {
    type    = "string"
    default = "sg-000000"
}

variable "lambda_webhook_timeout" {
    type    = "string"
    default = "20"
}

variable "api_stage" {
    type    = "string"
    default = "v1"
}

variable "webhook_domain" {
  default = "domain.com."
}

variable "webhook_dns" {
  default = "webhooks.domain.com"
}

variable "webhook_acm_certificate" {
  default = "domain.com"
}
