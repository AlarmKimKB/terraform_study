provider "aws" {
  profile = "default"
  region  = "ap-northeast-2"
}

# Service VPC by Terraform
# 1 VPC, 6 Subnet (2 Pub, 2 Pri, 2 DB), 1 Nat gw, 1 bastion

# VPC 생성
resource "aws_vpc" "vpc_svc_an2" {
  cidr_block           = var.vpc_cidr  # CIDR 범위는 vpc_cidr 변수에 지정
  enable_dns_support   = true          # dns 활성화
  enable_dns_hostnames = true          # dns 호스트네임 활성화
  tags = {
      Name = "vpc-svc-an2"
  }
}

# IGW 생성
resource "aws_internet_gateway" "igw_svc_an2" {
  vpc_id = aws_vpc.vpc_svc_an2.id
  tags = {
      Name = "igw-svc-an2"
  }
}

# Public Subnet 생성
resource "aws_subnet" "sn_svc_an2_pub" {
  count                   = length(var.sn_cidr_pub)             # 서브넷 개수는 sn_cidr_pub 변수의 개수
  vpc_id                  = aws_vpc.vpc_svc_an2.id
  cidr_block              = var.sn_cidr_pub[count.index]        # 각 서브넷의 CIDR 범위는 sn_cidr_pub 변수 순서대로 지정
  availability_zone       = var.availability_zones[count.index] # 각 서브넷의 AZ는 availability_zones 변수 순서대로 지정
  map_public_ip_on_launch = true                                # Public IP 사용 활성화 → Public 서브넷
  tags = {
      Name = "sn-svc-an2-pub-${var.az_for_name[count.index]}"
  }
}

# Private Subnet 생성
resource "aws_subnet" "sn_svc_an2_pri" {
  count               = length(var.sn_cidr_pri)                 # 서브넷 개수는 sn_cidr_pri 변수의 개수
  vpc_id              = aws_vpc.vpc_svc_an2.id
  cidr_block          = var.sn_cidr_pri[count.index]            # 각 서브넷의 CIDR 범위는 sn_cidr_pri 변수 순서대로 지정
  availability_zone   = var.availability_zones[count.index]     # 각 서브넷의 AZ는 availability_zones 변수 순서대로 지정
  tags = {
      Name = "sn-svc-an2-pri-${var.az_for_name[count.index]}"
  }
}

# DB Subnet 생성
resource "aws_subnet" "sn_svc_an2_db" {
  count               = length(var.sn_cidr_db)                  # 서브넷 개수는 sn_cidr_db 변수의 개수
  vpc_id              = aws_vpc.vpc_svc_an2.id
  cidr_block          = var.sn_cidr_db[count.index]             # 각 서브넷의 CIDR 범위는 sn_cidr_db 변수 순서대로 지정
  availability_zone   = var.availability_zones[count.index]     # 각 서브넷의 AZ는 availability_zones 변수 순서대로 지정
  tags  = {
      Name = "sn-svc-an2-db-${var.az_for_name[count.index]}"
  }
}

# NAT G/W를 위한 Elastic IP 생성
resource "aws_eip" "eip_nat_svc_an2" {
  count      = var.nat_count
  vpc        = true
  depends_on = ["aws_internet_gateway.igw_svc_an2"]             # IGW 생성 후에 Elastic IP를 생성 하겠다는 의미
  tags  = {
      Name = "eip-nat-svc-an2-${var.az_for_name[count.index]}"
  }
}

# NAT G/W 생성
resource "aws_nat_gateway" "nat_svc_an2" {
  count         = var.nat_count
  depends_on    = ["aws_internet_gateway.igw_svc_an2"]          # IGW 생성 후에 NAT G/W를 생성 하겠다는 의미
  allocation_id = aws_eip.eip_nat_svc_an2[count.index].id
  subnet_id     = aws_subnet.sn_svc_an2_pub[count.index].id     # NAT G/W가 1개이므로 연결되는 Public Subnet AZ는 첫번째로 생성되는 az-a
  tags = {
      Name = "nat-svc-an2${var.az_for_name[count.index]}"
  }
}

# Public Route Table 생성
resource "aws_route_table" "rtb_svc_an2_pub" {
  vpc_id = aws_vpc.vpc_svc_an2.id
  tags = {
      Name = "rtb-svc-an2-pub"
  }
}

# Public RTB Route 경로 설정
resource "aws_route" "rtb_route_svc_an2_pub" {
  route_table_id         = aws_route_table.rtb_svc_an2_pub.id  
  destination_cidr_block = "0.0.0.0/0"                              # 상위 Route Table ID에 대한 destination 경로
  gateway_id             = aws_internet_gateway.igw_svc_an2.id      # 연결할 IGW ID
}

# Public RTB 연결 Subnet 설정
resource "aws_route_table_association" "rtb_subnet_svc_an2_pub" {
  count          = length(var.sn_cidr_pub)                          # 연결할 Subnet은 Public Subnet 2개
  subnet_id      = aws_subnet.sn_svc_an2_pub[count.index].id        # 각각의 Public Subnet id 
  route_table_id = aws_route_table.rtb_svc_an2_pub.id               # 연결할 RTB ID
}

# Private Route Table 생성
resource "aws_route_table" "rtb_svc_an2_pri" {
  vpc_id = aws_vpc.vpc_svc_an2.id
  tags = {
      Name = "rtb-svc-an2-pri"
  }
}

# Private RTB Route 경로 설정
resource "aws_route" "rtb_route_svc_an2_pri" {
  count                  = var.nat_count
  route_table_id         = aws_route_table.rtb_svc_an2_pri.id
  destination_cidr_block = "0.0.0.0/0"                                    # 상위 Route Table ID에 대한 destination 경로
  nat_gateway_id         = aws_nat_gateway.nat_svc_an2[count.index].id    # 연결할 NAT G/W ID
}

# Private RTB 연결 Subnet 설정
resource "aws_route_table_association" "rtb_subnet_svc_an2_pri" {
  count          = length(var.sn_cidr_pri)                                # 연결할 Subnet은 Private Subnet 2개
  subnet_id      = aws_subnet.sn_svc_an2_pri[count.index].id              # 각각의 Private Subnet id
  route_table_id = aws_route_table.rtb_svc_an2_pri.id                     # 연결할 RTB ID
}

# DB Route Table 생성
resource "aws_route_table" "rtb_svc_an2_db" {
  vpc_id = aws_vpc.vpc_svc_an2.id
  tags = {
      Name = "rtb-svc-an2-db"
  }
}

# DB RTB Route 경로 설정
resource "aws_route" "rtb_route_svc_an2_db" {
  count                  = var.nat_count
  route_table_id         = aws_route_table.rtb_svc_an2_db.id
  destination_cidr_block = "0.0.0.0/0"                                   # 상위 Route Table ID에 대한 destination 경로
  nat_gateway_id         = aws_nat_gateway.nat_svc_an2[count.index].id   # 연결할 NAT G/W ID
}

# DB RTB 연결 Subnet 설정
resource "aws_route_table_association" "rtb_subnet_svc_an2_db" {
  count          = length(var.sn_cidr_db)                                # 연결할 Subnet은 DB Subnet 2개
  subnet_id      = aws_subnet.sn_svc_an2_db[count.index].id              # 각각의 DB Subnet id
  route_table_id = aws_route_table.rtb_svc_an2_db.id                     # 연결할 RTB ID
}

# 보안그룹 설정

# Public SG 생성
resource "aws_security_group" "scg_svc_an2_pub" {
  vpc_id        = aws_vpc.vpc_svc_an2.id
  name          = "scg-svc-an2-pub"
  description   = "scg-svc-an2-pub"
  ingress {                                         # Inbound Rule
    from_port   = 22                                # from_port부터 시작해서 to_port까지 열어주겠다.
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ssh from admin"
  }
  egress {                                          # Outbound Rule
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound Sample"
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "scg-svc-an2-pub"
  }
}

# Private SG 생성
resource "aws_security_group" "scg_svc_an2_pri" {                    # 80번 포트를 ALB 보안그룹으로부터 받는 설정을 위해 inrule 설정을 하지 않음
  vpc_id            = aws_vpc.vpc_svc_an2.id                         # source_security_group_id 옵션이 있어야 하는데, 루핑을 막기 위해 inrule에는 해당 옵션이 없음
  name              = "scg-svc-an2-pri"
  description       = "scg-svc-an2-pri"
  egress {                                                           # yum 설치를 위한 Outbound Open
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound Sample"
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "scg-svc-an2-pri"
  }
}

# Private SG Rule 생성 - ssh
resource "aws_security_group_rule" "scg_rule_svc_ssh" {
  type                     = "ingress"                                 # Inbound 설정
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.scg_svc_an2_pub.id     # Source 보안 그룹 (Public 보안그룹으로부터 들어오는 22번 포트 허용)
  security_group_id        = aws_security_group.scg_svc_an2_pri.id     # 현재 설정한 Rule을 적용할 보안 그룹
  description              = "ssh from bastion"
}

# Private SG Rule 생성 - http
resource "aws_security_group_rule" "scg_rule_svc_http" {
  type                     = "ingress"                                 # Inbound 설정
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.scg_svc_an2_alb_web.id # Source 보안 그룹 (ALB 보안그룹으로부터 들어오는 80번 포트 허용)
  security_group_id        = aws_security_group.scg_svc_an2_pri.id     # 현재 설정한 Rule을 적용할 보안 그룹
  description              = "http from alb"
}

# Public ALB SG 생성
resource "aws_security_group" "scg_svc_an2_alb_web" {
  vpc_id        = aws_vpc.vpc_svc_an2.id
  name          = "scg-svc-an2-alb-web"
  description   = "scg-svc-an2-alb-web"
  ingress {                                                            # Inbound Rule
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "http global service"
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "scg-svc-an2-alb-web"
  }
}

# ALB SG Rule 생성 - http to Pri-SG
resource "aws_security_group_rule" "scg_rule_svc_http_to_pri" {
  type                     = "egress"                                  # Outbound Rule
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.scg_svc_an2_pri.id     # 대상 보안 그룹 (Pri 보안그룹으로 나가는 80번 포트 허용)
  security_group_id        = aws_security_group.scg_svc_an2_alb_web.id # 현재 설정한 Rule을 적용할 보안 그룹
  description              = "http to web"
}

# EC2-Instance

# Bastion 생성
resource "aws_instance" "ec2_svc_an2_bastion" {
  count                  = var.bastion_count
  ami                    = "ami-014009fa4a1467d53"                    # EC2 AMI
  instance_type          = "t3.micro"                                 # EC2 타입
  subnet_id              = aws_subnet.sn_svc_an2_pub[count.index].id  # EC2 배포 서브넷
  availability_zone      = var.availability_zones[count.index]        # EC2 배포 가용 영역
  key_name               = "MZC-Keypair"                              # EC2 키페어
  vpc_security_group_ids = [aws_security_group.scg_svc_an2_pub.id]    # EC2 보안그룹
  iam_instance_profile   = "role-ec2"                                 # EC2 IAM Role
  tags = {
    Name = "ec2-svc-an2-bastion-${var.az_for_name[count.index]}"
  }
}

# Web EC2 생성
resource "aws_instance" "ec2_svc_an2_web" {
  count                  = var.web_server_count
  ami                    = "ami-014009fa4a1467d53"                    # EC2 AMI
  instance_type          = "t3.micro"                                 # EC2 타입
  subnet_id              = aws_subnet.sn_svc_an2_pri[count.index].id  # EC2 배포 서브넷
  availability_zone      = var.availability_zones[count.index]        # EC2 배포 가용 영역
  key_name               = "MZC-Keypair"                              # EC2 키페어
  vpc_security_group_ids = [aws_security_group.scg_svc_an2_pri.id]    # EC2 보안그룹
  iam_instance_profile   = "role-ec2"                                 # EC2 IAM Role
  user_data       = <<EOF
		#!/bin/bash
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    sudo echo helloworld > /var/www/html/index.html
    EOD
    EOF
  tags = {
    Name = "ec2-svc-an2-web-${var.az_for_name[count.index]}"
  }
}

# Application Load Balancer

# ALB Log 저장용 S3 생성
resource "aws_s3_bucket" "s3_alb_log" {
  bucket = "s3-alb-log-save-test-759343"                              # 버킷 이름
  tags = {
    Name = "s3-svc-alb-log"
  }
}

# S3 acl 설정
resource "aws_s3_bucket_acl" "s3_alb_log_acl" {
  bucket = aws_s3_bucket.s3_alb_log.id
  acl    = "private"
}

# S3 정책 생성
resource "aws_s3_bucket_policy" "s3_alb_log_policy" {
  bucket = aws_s3_bucket.s3_alb_log.id
  policy = data.aws_iam_policy_document.s3_policy_alb_log.json
}

# ALB Log 저장용 S3 정책 생성
data "aws_iam_policy_document" "s3_policy_alb_log" {
  statement {
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::600734575887:root"                              # 리전별 ELB 리소스 계정 ID, 서울리전은 600734575887
      ]
    }
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::s3-alb-log-save-test-759343/*"
    ]
  }
}

# ALB Log를 S3 버킷에 저장
output "s3_alb_log" {
value = "${aws_s3_bucket.s3_alb_log.bucket}"
}

# Target Group 생성
resource "aws_lb_target_group" "tg_svc_an2_web" {
  name     = "tg-svc-an2-web"
  port     = 80                                                       # Target Group 포트
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_svc_an2.id

  health_check {                                                      # ELB 헬스 체크
    interval            = 30                                          # 30초 간격
    path                = "/var/www/html/index.html"                  # 해당 위치로
    healthy_threshold   = 3                                           # 3번 보내서 성공하면 healthy로 간주
    unhealthy_threshold = 3                                           # 3번 보내서 실패하면 unhealthy로 간주
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "tg_att_svc_an2_web" {
  count            = var.web_server_count                             # Web Server 개수만큼 연결
  target_group_arn = aws_lb_target_group.tg_svc_an2_web.arn           # 적용할 Target Group 지정
  target_id        = aws_instance.ec2_svc_an2_web[count.index].id     # Web Server 모두 연결
  port             = 80
}

# ALB 생성
resource "aws_lb" "alb_svc_an2_web" {
  depends_on         = ["aws_lb_target_group.tg_svc_an2_web", "aws_s3_bucket.s3_alb_log"] # 해당 리소스가 생성된 후에 작업 시작
  name               = "alb-svc-an2-web"
  internal           = false                                                              # 외부 LB
  load_balancer_type = "application"                                                      # LB 타입
  security_groups    = [aws_security_group.scg_svc_an2_alb_web.id]
  subnets            = [for subnet in aws_subnet.sn_svc_an2_pub : subnet.id]              # LB가 생성될 서브넷 지정
  access_logs {                                                                           # Access Logs 생성
    bucket           = aws_s3_bucket.s3_alb_log.bucket
    prefix           = "alb-logs"
    enabled          = true
  }
  tags = {
    Name = "alb-svc-an2-web"
  }
}

# ALB Listener 규칙 생성
resource "aws_lb_listener" "alb-rule-svc-web" {
  load_balancer_arn  = aws_lb.alb_svc_an2_web.arn
  port               = "80"
  protocol           = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_svc_an2_web.arn
  }
}
