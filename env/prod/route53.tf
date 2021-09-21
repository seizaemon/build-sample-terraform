# DNS関連（Route 53）の設定

# 外部向けドメインのzone設定は消されると困るのでTerraformの管理外

# private zone
resource "aws_route53_zone" "private_zone" {
  name = local.public_domain

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

# records
resource "aws_route53_record" "front-alb" {
  zone_id = local.public_zone_id
  name    = "web.prod.${local.public_domain}"
  type = "A"

  alias {
    name = module.front-alb.lb_dns_name
    zone_id = module.front-alb.lb_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_route53_zone.private_zone]
}

resource "aws_route53_record" "private-alb" {
    zone_id = aws_route53_zone.private_zone.zone_id
    name    = "api.prod.${local.public_domain}"
    type = "A"

    alias {
        name = module.api-alb.lb_dns_name
        zone_id = module.api-alb.lb_zone_id
        evaluate_target_health = false
    }

    depends_on = [
        aws_route53_zone.private_zone, 
        module.api-alb
    ]
}
resource "aws_route53_record" "private-db" {
    zone_id = aws_route53_zone.private_zone.zone_id
    name    = "db.prod.${local.public_domain}"
    type    = "CNAME"
    ttl     = "300"
    records = [module.rds-aurora.rds_cluster_endpoint]

    depends_on = [
        aws_route53_zone.private_zone,
        module.rds-aurora
    ]
}