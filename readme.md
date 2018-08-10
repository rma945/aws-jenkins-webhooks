## Introduction

WebHooks service provides a simple API for [Jenkins SCM hooks](https://wiki.jenkins.io/display/JENKINS/PollSCM+Plugin), that can trigger your internal Jenkins instances from services that don`t have access to your local environment, like [GitHub](https://github.com) or [BitBucket](https://bitbucket.org).

This terraform package contains 2 service -  **API Gateway**, and **Lambda**.

**API Gateway** service parses incoming payload and then execute Lambda function that trigger list of Jenkins instances.

**Lambda function** call PollSCM plugin on Jenkins servers one-by-one


## Deployment

Initialize terraform configuration

```
terraform init -backend-config=config.tfvars
```

Prepare Lambda package for deployment
```
zip -r webhooks_lambda.zip main.py
```

Perform deployment with default variables.tf configuration
```
terraform apply
```

Perform deployment with custom configuration
```
terraform apply \
    -var environment_prefix=company \
    -var lambda_webhook_subnets_id=subnet-xxxxxxx \
    -var lambda_webhook_sg_id=sg-xxxxxxx \
    -var lambda_webhook_timeout=20 \
    -var api_stage=v1 \
    -var webhook_domain=domain.com. \
    -var webhook_dns=domain.com \
    -var webhook_acm_certificate=domain.com
```

After deployment you got invocation URL for deployed API, so you can use it on your CI hooks.

### Usage

* POST: https://invoke_url/v1/{service}/{type}/
* GET: https://invoke_url/v1/custom/{type}?remote={repository_url}

### {service}

For **{service}** key you can specify service name, who invokes this hook:

* github
* bitbucket
* custom

For bitbucket\github services - API gateways parse request payload and generate custom payload for Lambda

### {type}

For **{type}** key you can specify Jenkins service type for invoke only this Jenkins instance:

* any | all
* ios
* android
* docker
* windows

For custom hooks you should use **GET** method with **remote** argument that point to repository URL

```
https://invoke_url/v1/custom/docker?remote=ssh://repository/project.git
```

## GitHub

![GitHub webhook integration example](https://github.com/rma945/aws-jenkins-webhooks/raw/develop/.images/github.png "GitHub webhook integration example")


## BitBucket

![BitBucket webhook integration example](https://github.com/rma945/aws-jenkins-webhooks/raw/develop/.images/bitbucket.png "BitBucket webhook integration example")
