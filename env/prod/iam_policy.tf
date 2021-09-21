resource "aws_iam_role" "this" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

module "policy-codedeploy-s3access" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.3"

  name        = "CodedeployS3access"
  path        = "/"
  description = "S3 access for codedeploy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

data "aws_iam_policy_document" "policy-projectS3" {
  statement {
    actions = [
        "s3:Get*",
        "s3:List*",
        "s3:Put*"
    ]
    resources = [
      "arn:aws:s3:::${local.s3_project_bucket}",
    ]
  }
}

module "policy-projectS3" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
    version = "~> 4.3"

    name        = "PutS3access"
    path        = "/"
    description = "S3 access for Application"
    policy = data.aws_iam_policy_document.policy-projectS3.json
}

module "policy-get-ssm-parameters" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.3"

  name        = "tmpSSMParametersGet"
  path        = "/"
  description = "Get value from SSM Parameter Store"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:ap-northeast-1:432699281199:parameter/tmp*"
        }
    ]
}
EOF
}