# APIとAPI gateway用の設定

# APIインスタンス用AutoScaling Group API用プライベートALB
# API GatewayとALBをつなぐVPC link

# S3（ALBログ置き場）
module "s3-api-alb-log" {
    source  = "terraform-aws-modules/s3-bucket/aws"
    version = "2.9.0"

    bucket = "tmp-api-alb-logs"
    acl = "log-delivery-write"
    attach_elb_log_delivery_policy = true
}

# ALB
data "aws_subnet" "private-lb1" {
    cidr_block = local.private_subnet_data["private-lb-subnet-1"]
    depends_on = [module.vpc]
}
data "aws_subnet" "private-lb2" {
    cidr_block = local.private_subnet_data["private-lb-subnet-2"]
    depends_on = [module.vpc]
}

module "api-alb" {
    source  = "terraform-aws-modules/alb/aws"
    version = "6.5.0"

    name = "api-alb"

    vpc_id = module.vpc.vpc_id
    subnets = [
        data.aws_subnet.private-lb1.id,
        data.aws_subnet.private-lb2.id
    ]

    security_groups = [module.private-lb-sg.security_group_id]
    load_balancer_type = "application"
    internal = true

    access_logs = {
        bucket = module.s3-api-alb-log.s3_bucket_id
    }

    target_groups = [
        {
            name_prefix      = "api-"
            backend_protocol = "HTTP"
            backend_port     = 80
            target_type      = "instance"
            target_group_tags = {
                application = "front"
            }
        }
    ]

    http_tcp_listeners = [{
        port = 80
        protocol           = "HTTP"
        target_group_index = 0
    }]
}

# IAM instance-profile(for EC2)
module "api-instance-role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
    version = "4.5.0"

    create_role = true
    create_instance_profile = true
    trusted_role_services = ["ec2.amazonaws.com"]

    role_name = "api-instance-role"
    number_of_custom_role_policy_arns = 5

    custom_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        module.policy-codedeploy-s3access.arn,
        module.policy-get-ssm-parameters.arn,
        module.policy-projectS3.arn
    ]
    role_requires_mfa = false
}


# EC2 (auto scaling)
module "api-asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"

    # Autoscaling group
    name = "api-asg"

    ## サイズ（とりあえず一個だけ)
    min_size                  = 1
    max_size                  = 1
    desired_capacity          = 1

    wait_for_capacity_timeout = 0
    health_check_type         = "EC2"
    vpc_zone_identifier       = [
        module.vpc.private_subnets[0], module.vpc.private_subnets[1]
    ]

    user_data_base64 = filebase64("./ec2-userdata/init.sh")

    # ALBとの接続
    target_group_arns = module.api-alb.target_group_arns

    # インスタンスが1つなので設定しない
    # instance_refresh = {
    #     strategy = "Rolling"
    #     preferences = {
    #         min_healthy_percentage = 50
    #     }
    #     triggers = ["tag"]
    # }

    ##### ここから Launch template
    lt_name                = "api-asg-launch"
    description            = "Launch template for api"
    update_default_version = true

    use_lt    = true
    create_lt = true

    iam_instance_profile_name = module.api-instance-role.iam_instance_profile_name

    ## Amazon Linux AMI
    image_id          = "ami-02892a4ea9bfa2192"
    instance_type     = "t3.medium"
    ebs_optimized     = true
    enable_monitoring = true
    key_name = local.key_pair_name
    # user_data_base64 = 

    ## Root volume only
    block_device_mappings = [
        {

            device_name = "/dev/xvda"
            no_device   = 0
            ebs = {
                delete_on_termination = true
                encrypted             = true
                volume_size           = 40
                volume_type           = "gp3"
            }
        }
    ]

    network_interfaces = [
        {
            delete_on_termination = true
            description           = "eth0"
            device_index          = 0
            security_groups       = [module.api-sg.security_group_id]
        },
    ]

    tag_specifications = [
        {
            resource_type = "instance"
            tags          = { WhatAmI = "Instance" }
        },
        {
            resource_type = "volume"
            tags          = { WhatAmI = "Volume" }
        },
    ]

    tags = [
        {
            key                 = "application"
            value               = "api"
            propagate_at_launch = true
        }
    ]
}

# API gateway
module "public-apigateway" {
    source  = "terraform-aws-modules/apigateway-v2/aws"
    version = "1.3.0"

    name          = "public-api-gw"
    description   = "API gateway for customer"
    protocol_type = "HTTP"

    domain_name = local.api_domain
    domain_name_certificate_arn = local.ssl_cert_arn
    
    # CORS
    cors_configuration = {
        allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
        allow_methods = ["*"]
        allow_origins = ["*"]
    }


    integrations = {
        "ANY /" = {
            connection_type    = "VPC_LINK"
            vpc_link           = "apigw-private-link"
            integration_uri    = module.api-alb.http_tcp_listener_arns[0]
            integration_type   = "HTTP_PROXY"
            integration_method = "ANY"
        }
    }

    vpc_links = {
        apigw-private-link = {
            name               = "apigw-private-link"
            security_group_ids = [module.apigw-sg.security_group_id]
            subnet_ids         = [
                module.vpc.private_subnets[0],
                module.vpc.private_subnets[1]
            ]
        }
    }
}
