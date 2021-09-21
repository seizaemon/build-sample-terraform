variable "username" {}
variable "access_token" {}

terraform {
    required_providers {
        aws = {
            version = "~> 3.59.0"
            source = "hashicorp/aws"
        }
    }

    backend "http" {
        config = {
            address = "https://XXXXX"
            username = "${var.username}"
            password = "${var.access_token}"
        }
    }
}
provider "aws" {
    region = "ap-northeast-1"
    # 全リソース共通に入るタグ
    default_tags {
        tags = {
            Environment = "production"
            Terraform = "true"
        }
    }
}

# プロジェクト全体で利用する変数
locals {
    environment = "prod"

    # 使用するドメインとRoute53のゾーンID
    public_domain = "mytemporary.site"
    public_zone_id = "XXXXXXXXXXX"
    api_domain = "api.prod.${local.public_domain}"
    web_domain = "web.prod.${local.public_domain}"

    # ネットワークサブネット
    private_subnet_data = {
        "api-subnet-1" = "172.11.20.0/24"
        "api-subnet-2" = "172.11.21.0/24"
        "apigw-link-subnet" = "172.11.29.0/24"
        "private-lb-subnet-1" = "172.11.25.0/24"
        "private-lb-subnet-2" = "172.11.26.0/24"
        "front-subnet-1" = "172.11.30.0/24"
        "front-subnet-2" = "172.11.31.0/24"
        "scraping-subnet" = "172.11.100.0/24"
    }

    public_subnet_data = {
        "public-subnet-1" = "172.11.0.0/24"
        "public-subnet-2" = "172.11.1.0/24"
        "admin-subnet" = "172.11.40.0/24"
    }

    database_subnet_data = {
        "db-subnet-1" = "172.11.10.0/24"
        "db-subnet-2" = "172.11.11.0/24"
        "db-subnet-3" = "172.11.12.0/24"
    }

    # DB関連
    db_admin_user = "admin"
    db_admin_password = ""
    db_name = "db_name"

    # プロジェクト用S3バケット名（ここにはフルアクセス可能）
    s3_project_bucket = "project-tmp"

    # SSM parameter storeの場所
    ssm_api_path = "/tmp/api/production"
    ssm_env_api = file("./ssm-parameters/api.txt")
    ssm_front_path = "/tmp/front/production"
    ssm_env_front = file("./ssm-parameters/front.txt")
    ssm_admin_path = "/tmp/admin/production"
    ssm_env_admin = file("./ssm-parameters/admin.txt")
    ssm_scraping_path = "/tmp/scraping/production"
    #ssm_env_scraping = file("./ssm-parameters/scraping.txt")

    ## SSL証明書のARN（あらかじめASMで作成してください）
    ssl_cert_arn = ""

    # key-pair tmp-prod （terraformの管理下にはありません）)
    key_pair_name = "tmp-prod"
    region = "ap-northeast-1"

    # adminのアクセス制限先IPリスト
    admin_allow_ipaddr = ["0.0.0.0/0"]
}
