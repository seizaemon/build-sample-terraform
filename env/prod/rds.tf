module "rds-aurora" {
    source  = "terraform-aws-modules/rds-aurora/aws"
    version = "5.2.0"

    name           = "tmp-db"
    engine         = "aurora-mysql"
    engine_version = "5.7.mysql_aurora.2.09.2"
    instance_type  = "db.t4g.large"
    database_name = local.db_name
    replica_count = 1
    port = 3306

    vpc_id = module.vpc.vpc_id
    subnets = module.vpc.database_subnets
    allowed_security_groups = [module.api-sg.security_group_id]

    # 認証
    username = local.db_admin_user
    create_random_password = false
    password = local.db_admin_password

    # メンテナンス
    enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery", "general"]
    auto_minor_version_upgrade = true
    # 表記はUTCであることに注意
    preferred_backup_window = "17:00-18:00"
    preferred_maintenance_window  = "fri:19:00-fri:20:00"

    storage_encrypted   = true
    monitoring_interval = 60
}