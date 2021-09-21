#!/bin/bash

# サーバ起動用userdata
# Autoscaling groupの起動設定にセットします。（以下のコマンドでbase64化する必要があります）
# $ base64 userdata.sh

# ここでは最低限必要なAgentのインストールのみ実施します。
# 必要なライブラリのインストールや設定の変更などはデプロイ時に実施します。

readonly WORKDIR='/tmp'

yum -y update
### SSM agent
readonly SSM_AGENT_INSTALLER='https://s3.ap-northeast-1.amazonaws.com/amazon-ssm-ap-northeast-1/latest/linux_amd64/amazon-ssm-agent.rpm'
yum install -y "${SSM_AGENT_INSTALLER}"
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

### Cloudwatch agent
yum install -y amazon-cloudwatch-agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s

# CodeDeploy Agentのインストーラー置き場
# https://docs.aws.amazon.com/ja_jp/codedeploy/latest/userguide/resource-kit.html#resource-kit-bucket-names
readonly CODEDEPLOY_AGENT_INSTALLER='https://aws-codedeploy-ap-northeast-1.s3.ap-northeast-1.amazonaws.com/latest/install'

# codedeploy agent install
yum -y install ruby wget git
wget "${CODEDEPLOY_AGENT_INSTALLER}"
chmod +x ./install
./install auto


