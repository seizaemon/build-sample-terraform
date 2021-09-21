# nw segment と security groupはnetwork.tfで作成済み

# SSL証明書(ACMで作成するが消されたくないので、Terraform管理下にしない)
# module "front-acm" {
#     source  = "terraform-aws-modules/acm/aws"
#     version = "3.2.0"

#     domain_name  = local.public_domain
#     zone_id = local.public_zone_id

#     subject_alternative_names = [
#         "*.${local.public_domain}",
#     ]

#     wait_for_validation = true
# }

# S3（ALBログ置き場）
module "s3-front-alb-log" {
    source  = "terraform-aws-modules/s3-bucket/aws"
    version = "2.9.0"

    bucket = "tmp-front-alb-logs"
    acl = "log-delivery-write"
    attach_elb_log_delivery_policy = true
}

data "aws_subnet" "front-public1" {
    cidr_block = local.public_subnet_data["public-subnet-1"]
    depends_on = [module.vpc]
}
data "aws_subnet" "front-public2" {
    cidr_block = local.public_subnet_data["public-subnet-2"]
    depends_on = [module.vpc]
}

# ALB
module "front-alb" {
    source  = "terraform-aws-modules/alb/aws"
    version = "6.5.0"

    name = "front-alb"

    vpc_id = module.vpc.vpc_id
    subnets = [
        data.aws_subnet.front-public1.id, 
        data.aws_subnet.front-public2.id
    ]
    security_groups = [module.public-sg.security_group_id]
    load_balancer_type = "application"


    access_logs = {
        bucket = module.s3-front-alb-log.s3_bucket_id
    }

    target_groups = [
        {
            name_prefix      = "front-"
            backend_protocol = "HTTP"
            backend_port     = 80
            target_type      = "instance"
            target_group_tags = {
                application = "front"
            }
        }
    ]

    https_listeners = [
        {
            port = 443
            certificate_arn = "${local.ssl_cert_arn}"
        }
    ]


    https_listener_rules = [
        {
            https_listener_index = 0
            priority = 100

            actions = [{
                type = "forward"
                target_group_index = 0
            }]
            conditions = [{
                host_headers = ["${local.web_domain}"]
            }]
        }
    ]
}

# IAM instance-profile(for EC2)
module "front-instance-role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
    version = "4.5.0"

    create_role = true
    create_instance_profile = true
    trusted_role_services = ["ec2.amazonaws.com"]

    role_name = "front-instance-role"
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
module "front-asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.0"

    # Autoscaling group
    name = "front-asg"

    ## サイズ（とりあえず一個だけ)
    min_size                  = 1
    max_size                  = 1
    desired_capacity          = 1

    wait_for_capacity_timeout = 0
    health_check_type         = "EC2"
    vpc_zone_identifier       = [
        module.vpc.private_subnets[2], module.vpc.private_subnets[3]
    ]

    user_data_base64 = filebase64("./ec2-userdata/init.sh")

    # ALBとの接続
    target_group_arns = module.front-alb.target_group_arns

    # インスタンスが1つなので設定しない
    # instance_refresh = {
    #     strategy = "Rolling"
    #     preferences = {
    #         min_healthy_percentage = 50
    #     }
    #     triggers = ["tag"]
    # }

    # Launch template
    lt_name                = "front-asg-launch"
    description            = "Launch template for front"
    update_default_version = true

    use_lt    = true
    create_lt = true

    iam_instance_profile_name = module.front-instance-role.iam_instance_profile_name

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
            security_groups       = [module.front-sg.security_group_id]
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
            value               = "front"
            propagate_at_launch = true
        }
    ]
}

