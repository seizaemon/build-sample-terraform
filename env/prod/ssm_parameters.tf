# resource "aws_ssm_parameter" "api_this" {
#     for_each = { for line in csvdecode(local.ssm_env_api) : line.env_key => line.env_value }

#     name  = "${local.ssm_api_path}/${each.key}"
#     type  = "String"
#     value = each.value
# }

# DB関連(直接接続するのはapiとscrapingのみ）
resource "aws_ssm_parameter" "db_host" {
    for_each = toset([local.ssm_api_path, local.ssm_scraping_path])

    name = "${each.key}/DB_HOST"
    type = "String"
    value = module.rds-aurora.rds_cluster_endpoint
}
resource "aws_ssm_parameter" "db_user" {
    for_each = toset([local.ssm_api_path, local.ssm_scraping_path])

    name = "${each.key}/DB_USERNAME"
    type = "String"
    value = module.rds-aurora.rds_cluster_master_username
}

resource "aws_ssm_parameter" "db_password" {
    for_each = toset([local.ssm_api_path, local.ssm_scraping_path])

    name = "${each.key}/DB_PASSWORD"
    type = "String"
    value = module.rds-aurora.rds_cluster_master_password
}
resource "aws_ssm_parameter" "db_name" {
    for_each = toset([local.ssm_api_path, local.ssm_scraping_path])

    name = "${each.key}/DB_DATABASE"
    type = "String"
    value = local.db_name
}

# プロジェクトS3バケット関連
resource "aws_ssm_parameter" "project_s3" {
    for_each = toset([
        local.ssm_api_path,
        local.ssm_admin_path,
        local.ssm_api_path,
        local.ssm_scraping_path,
        local.ssm_front_path
    ])

    name = "${each.key}/AWS_BUCKET"
    type = "String"
    value = local.s3_project_bucket
}

