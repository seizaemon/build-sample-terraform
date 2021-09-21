# 社内管理用インスタンスの設定
## adminは社内用のため単発のインスタンスで起動する

# IAM instance-profile(for EC2)
module "admin-instance-role" {
    source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
    version = "4.5.0"

    create_role = true
    create_instance_profile = true
    trusted_role_services = ["ec2.amazonaws.com"]

    role_name = "admin-instance-role"
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

data "aws_subnet" "admin-subnet" {
    cidr_block = local.public_subnet_data["admin-subnet"]
    depends_on = [module.vpc]
}

module "admin-instance" {
    source  = "terraform-aws-modules/ec2-instance/aws"
    version = "3.1.0"

    name = "admin-instance"

    ## Amazon Linux AMI
    ami = "ami-02892a4ea9bfa2192"
    instance_type          = "t3.medium"
    key_name               = local.key_pair_name
    monitoring             = true
    vpc_security_group_ids = [module.admin-sg.security_group_id]
    subnet_id              = data.aws_subnet.admin-subnet.id

    user_data_base64 = filebase64("./ec2-userdata/init.sh")

    iam_instance_profile = module.admin-instance-role.iam_role_name

    tags = {
        application = "admin"
    }
}
