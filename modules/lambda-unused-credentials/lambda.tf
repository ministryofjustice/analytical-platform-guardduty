# -----------------------------------------------------------
# set up AWS Cloudwatch Event every Monday to Friday at 9am
# -----------------------------------------------------------

resource "aws_cloudwatch_event_rule" "schedule" {
  schedule_expression = "cron(0 9 * * 1-5 *)"
}

# -----------------------------------------------------------
# Create IAM Role for unused credentials lambda
# -----------------------------------------------------------

resource "aws_iam_role" "lambda_unused_credentials_role" {
  name = "${var.lambda_unused_credentials_role}"
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

# -----------------------------------------------------------
# set up AWS Cloudwatch Event to target a lambda function
# -----------------------------------------------------------

resource "aws_cloudwatch_event_target" "main" {
  rule      = "${var.schedule}"
  arn       = "${aws_lambda_function.lambda_unused_credentials.arn}"
}

resource "aws_lambda_function" "lambda_unused_credentials" {
  filename         = "${var.filename}"
  function_name    = "${var.lambda_function_name}"
  role             = "${aws_iam_role.lambda_unused_credentials_role.arn}"
  handler          = "sns_unused_credentials.lambda_handler"
  source_code_hash = "${base64sha256(var.filename)}"
  runtime          = "python3.7"
  environment {
    variables = {
      SNS_TOPIC_ARN = "${sns_topic_arn}"
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_unused_credentials_log" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

# -----------------------------------------------------------
# Collect Email SSM Parameters
# -----------------------------------------------------------

data "aws_ssm_parameter" "unused_credentials_emails" {
  name = "${var.ssm_unused_credentials_emails}"
}

# -----------------------------------------------------------
# Create policy for logging
# -----------------------------------------------------------

resource "aws_iam_policy" "unused_credentials_log_policy" {
  name = "${var.unused_credentials_log_policy}"
  description = "IAM policy for logging from lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# -----------------------------------------------------------
# Attach Logging Policy to Lambda role
# -----------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = "${aws_iam_role.lambda_unused_credentials_role.name}"
  policy_arn = "${aws_iam_policy.unused_credentials_log_policy.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.lambda_unused_credentials.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.schedule.arn}"
}

# -----------------------------------------------------------
# AWS SNS topic (https://www.terraform.io/docs/providers/aws/r/sns_topic_subscription.html#email)
# -----------------------------------------------------------

resource "aws_cloudformation_stack" "sns_topic" {
  name          = "${var.stack_name}"
  template_body = "${data.template_file.cloudformation_sns_stack.rendered}"
}

# -----------------------------------------------------------
# Use Cloudformation template for EMAIL SNS Topic
# -----------------------------------------------------------

data "template_file" "cloudformation_sns_stack" {
  template = "${file("${path.module}/templates/email-sns-stack.json.tpl")}"
  vars {
    display_name  = "${var.display_name}"
    subscriptions = "${join("," , formatlist("{ \"Endpoint\": \"%s\", \"Protocol\": \"%s\" }", data.aws_ssm_parameter.unused_credentials_email.value, var.protocol))}"
  }
}