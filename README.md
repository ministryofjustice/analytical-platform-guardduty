# Analytical Platform AWS Security

AWS Baseline for all Analytical Platform AWS Accounts. This project is composed of several modules specialised in AWS Security components.

## Description

This Terraform repository would do the following:

* Enable AWS GuardDuty
* Enable AWS Config
* Enable AWS SecurityHub
* Implement a lambda scanning for unused credentials
* Implement a lambda scanning S3 Public buckets
* Implement a lambda scanning S3 Bucket encryption
* Enable trails from AWS Cloudtrail and centralise logs in AWS Security Account

## Usage

Each terraform files at the root level of this project have specific function. As an example, lets enable Security AWS GuardDuty in the landing AWS Account for alerting on various findings. We'll also invite and enable another aws account, and link it to AWS GuardDuty in the landing AWS account.

### AWS GuardDuty master

By calling `guardduty-master` module, this would enable AWS GuardDuty in the selected account, and outputs necessary variables for other terraform modules.

```hcl
module "aws_guardduty_master" {
  source                    = "modules/guardduty-master"

  providers = {
    aws = "aws.account"
  }

  assume_role_in_account_id = "${var.ap_accounts["landing"]}"
}
```

### AWS GuardDuty invitation

After creating Guardduty Master, this module would send an invitation to its members. This module requires GuardDuty Master ID, the value exported from previous module.  

```hcl
module "aws_guardduty_invite_dev" {
  source                    = "modules/guardduty-invitation"

  providers = {
    aws = "aws.account"
  }

  detector_master_id        = "${module.aws_guardduty_master.guardduty_master_id}"
  email_member_parameter    = "${var.email_member_parameter_dev}"
  member_account_id         = "${var.ap_accounts["dev"]}"
}
```

### AWS GuardDuty members

AWS GuardDuty member module would enable GuardDuty in the selected account, accept invitation from master and start sending event to GuardDuty Master.

```hcl
module "aws_guardduty_member_dev" {
  source                    = "modules/guardduty-member"

  providers = {
    aws = "aws.account"
  }

  master_account_id         = "${var.ap_accounts["landing"]}"
}
```

### AWS GuardDuty SNS notifications

Final module, required module to send notifications to a selected Slack Channel.

```hcl
module "aws_guardduty_sns_notifications" {
  source                     = "modules/sns-guardduty-slack"

  providers = {
    aws = "aws.account"
  }

  event_rule                 = "${module.aws_guardduty_master.guardduty_event_rule}"
  ssm_slack_channel          = "${var.ssm_slack_channel}"
  ssm_slack_incoming_webhook = "${var.ssm_slack_incoming_webhook}"
}
```

## Prerequisites

Install:

* [Terraform](https://www.terraform.io/docs/)
* [Terraform IAM Role](https://github.com/ministryofjustice/analytical-platform-aws-security/tree/master/init-roles)

## Manual `terraform plan`

To test a PR you can do a terraform plan locally e.g.

```bash
aws-vault exec landing-admin -- terraform init
aws-vault exec landing-admin -- terraform plan -var-file=vars/ap_accounts.tfvars
```

## Deployment

This project is using AWS CodePipeline to deploy modules in multiple AWS Accounts.

* [Pipeline](https://eu-west-1.console.aws.amazon.com/codesuite/codepipeline/pipelines/aws-security/view?region=eu-west-1)
* [Terraform definition of the pipeline](pipeline/README.md)
