# main vpc
module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "3.7.0"

    name = "tmp-vpc"
    cidr = "172.11.0.0/16"
    azs  = ["${local.region}a", "${local.region}c"]

    database_subnets = [ for name, cidr in local.database_subnet_data : cidr ]
    private_subnets = [ for name, cidr in local.private_subnet_data : cidr  ]
    public_subnets  = [ for name, cidr in local.public_subnet_data : cidr ]

    # NAT（全体で一個だけ）
    enable_nat_gateway = true
    single_nat_gateway = true
    one_nat_gateway_per_az = false

    # DNS
    enable_dns_hostnames = true
    enable_dns_support   = true

    # DB
    ## 上記で意図的にDB subnetを作成しているので自動では作成しない
    create_database_subnet_group = false
    database_subnet_group_name = "tmp-db-subnet"


    private_subnet_tags = {
        VPC = "tmp-vpc"
    }

    vpc_tags = {
        Name = "tmp-vpc"
    }

}

# security groups (public)
module "public-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "public-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_cidr_blocks = ["0.0.0.0/0"]
    ingress_rules = ["https-443-tcp"]

    tags = {
        Name = "public-sg"
    }
}

module "admin-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "admin-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_cidr_blocks = local.admin_allow_ipaddr
    ingress_rules = ["https-443-tcp"]

    tags = {
        Name = "admin-sg"
    }
}

# security groups (private)
module "db-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "db-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_with_source_security_group_id = [
        {
            rule                     = "mysql-tcp"
            source_security_group_id = module.api-sg.security_group_id
        },
        {
            rule                     = "mysql-tcp"
            source_security_group_id = module.scraping-sg.security_group_id
        },
    ]
    tags = {
        Name = "db-sg"
    }
}
module "api-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "api-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_with_source_security_group_id = [
        {
            rule = "http-80-tcp"
            source_security_group_id = module.private-lb-sg.security_group_id
        },
    ]
    tags = {
        Name = "api-sg"
    }
}

module "apigw-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "apigw-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_with_source_security_group_id = [
        {
            rule = "all-all"
            source_security_group_id = module.private-lb-sg.security_group_id
        },
    ]
}

module "private-lb-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "provate-lb-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_with_source_security_group_id = [
        {
            rule = "http-80-tcp"
            source_security_group_id = module.front-sg.security_group_id
        },
        {
            rule = "http-80-tcp"
            source_security_group_id = module.admin-sg.security_group_id
        },
        {
            rule = "http-80-tcp"
            source_security_group_id = module.apigw-sg.security_group_id
        },
        {
            rule = "http-80-tcp"
            source_security_group_id = module.scraping-sg.security_group_id
        },
    ]
}

module "front-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "front-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_with_source_security_group_id = [
        {
            rule = "http-80-tcp"
            source_security_group_id = module.public-sg.security_group_id
        },
    ]
    tags = {
        Name = "front-sg"
    }
}


module "scraping-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "scraping-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]

    tags = {
        Name = "scraping-sg"
    }
}

module "ssm-sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.3.0"

    name = "ssm-sg"
    vpc_id = module.vpc.vpc_id

    egress_cidr_blocks = ["0.0.0.0/0"]
    egress_rules = ["all-all"]
    ingress_with_source_security_group_id = [
        {
            rule = "all-all"
            source_security_group_id = module.api-sg.security_group_id
        },
        {
            rule = "all-all"
            source_security_group_id = module.front-sg.security_group_id
        },
        {
            rule = "all-all"
            source_security_group_id = module.db-sg.security_group_id
        },
        {
            rule = "all-all"
            source_security_group_id = module.admin-sg.security_group_id
        },
        {
            rule = "all-all"
            source_security_group_id = module.scraping-sg.security_group_id
        },
    ]
    tags = {
        Name = "ssm-sg"
    }
}

# VPC endpoint
module "endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id = module.vpc.vpc_id
  security_group_ids = [module.ssm-sg.security_group_id]

  endpoints = {
    s3 = {
        # interface endpoint
        service             = "s3"
        subet_ids = [
            module.vpc.private_subnets[0],
            module.vpc.private_subnets[1]
        ] 
        tags                = { Name = "s3-vpc-endpoint" }
    },
    ssm = {
        # interface endpoint
        service             = "ssm"
        subet_ids = [
            module.vpc.private_subnets[0],
            module.vpc.private_subnets[1]
        ]
        tags                = { Name = "ssm-vpc-endpoint" }
    },
    codedeploy = {
        # interface endpoint
        service             = "codedeploy"
        subet_ids = [
            module.vpc.private_subnets[0],
            module.vpc.private_subnets[1]
        ]
        tags                = { Name = "codedeploy-vpc-endpoint" }
    }
  }
}