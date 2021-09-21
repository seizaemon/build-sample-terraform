# S3バケットの設定（共通で利用するもの）
## ログの置き場などに使用するバケットは、そのアプリケーションを管轄するtfで設定しています。

# プロジェクト共通S3バケット
module "s3-common-data" {
    source  = "terraform-aws-modules/s3-bucket/aws"
    version = "2.9.0"

    bucket = "tmp-pvv"
    acl  = "private"
}