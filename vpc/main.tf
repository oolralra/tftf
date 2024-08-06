terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# VPC 정의
resource "aws_vpc" "this" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "eks-vpc"
  }
}

# IGW 생성
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${aws_vpc.this.tags["Name"]}-igw"
  }
}

# NATGW 탄력적 주소 생성
resource "aws_eip" "this" {
  

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "min-eip-ngw"
  }
}

# NAT 게이트웨이 생성
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.pub_sub1.id

  tags = {
    Name = "min-ngw"
  }

  lifecycle {
    create_before_destroy = true
  }

  # depends_on = [aws_internet_gateway.this]
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "pub_sub1" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = "10.50.10.0/24"
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  availability_zone                           = "ap-northeast-2a"
  tags = {
    Name                        = "pub-sub1"
    "kubernetes.io/cluster/pri-cluster" = "owned"
    "kubernetes.io/role/elb"           = "1"
  }
  depends_on = [aws_internet_gateway.this]
}

resource "aws_subnet" "pub_sub2" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = "10.50.11.0/24"
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  availability_zone                           = "ap-northeast-2c"
  tags = {
    Name                        = "pub-sub2"
    "kubernetes.io/cluster/pri-cluster" = "owned"
    "kubernetes.io/role/elb"           = "1"
  }
  depends_on = [aws_internet_gateway.this]
}

# 프라이빗 서브넷 생성
resource "aws_subnet" "pri_sub1" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = "10.50.20.0/24"
  enable_resource_name_dns_a_record_on_launch = true
  availability_zone                           = "ap-northeast-2a"
  tags = {
    Name                        = "pri-sub1"
    "kubernetes.io/cluster/pri-cluster" = "owned"
    "kubernetes.io/role/internal-elb"   = "1"
  }
}

resource "aws_subnet" "pri_sub2" {
  vpc_id                                      = aws_vpc.this.id
  cidr_block                                  = "10.50.21.0/24"
  enable_resource_name_dns_a_record_on_launch = true
  availability_zone                           = "ap-northeast-2c"
  tags = {
    Name                        = "pri-sub2"
    "kubernetes.io/cluster/pri-cluster" = "owned"
    "kubernetes.io/role/internal-elb"   = "1"
  }
}

# 퍼블릭 라우팅 테이블 생성
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  route {
    cidr_block = "10.50.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "min-rtb-pub"
  }
  depends_on = [aws_internet_gateway.this]
}

# 프라이빗 라우팅 테이블 생성
resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.this.id
  }

  route {
    cidr_block = "10.50.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "min-rtb-pri"
  }

  depends_on = [aws_nat_gateway.this]
}

# 라우팅 테이블 + 서브넷 연결
resource "aws_route_table_association" "min_rtb_association_pub_1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "min_rtb_association_pub_2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "min_rtb_association_pri_1" {
  subnet_id      = aws_subnet.pri_sub1.id
  route_table_id = aws_route_table.pri_rt.id
}

resource "aws_route_table_association" "min_rtb_association_pri_2" {
  subnet_id      = aws_subnet.pri_sub2.id
  route_table_id = aws_route_table.pri_rt.id
}

# 종속성을 명확히 하기 위한 설정
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.this.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 퍼블릭 보안그룹 생성
resource "aws_security_group" "min-pub-sg" {
  vpc_id = aws_vpc.this.id
  name = "min-pub-sg"
  tags = {
    Name = "min-pub-sg"
  }
}

# 프라이빗 보안그룹 생성
resource "aws_security_group" "min-pri-sg" {
  vpc_id = aws_vpc.this.id
  name = "min-pri-sg"
  tags = {
    Name = "min-pri-sg"
  }
}

# 프라이빗 DB 보안그룹 생성
resource "aws_security_group" "min-pri-db-sg" {
  vpc_id = aws_vpc.this.id
  name = "min-pri-db-sg"
  tags = {
    Name = "min-pri-db-sg"
  }
}

# 퍼블릭 보안그룹 http 인그리스 규칙
resource "aws_security_group_rule" "min-pub-http-ingress" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "TCP"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.min-pub-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 퍼블릭 보안그룹 https 인그리스 규칙
resource "aws_security_group_rule" "min-pub-https-ingress" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "TCP"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.min-pub-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 퍼블릭 보안그룹 ssh 인그리스 규칙
resource "aws_security_group_rule" "min-pub-ssh-ingress" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "TCP"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.min-pub-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 퍼블릭 보안그룹 egress 규칙
resource "aws_security_group_rule" "min-pub-egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.min-pub-sg.id
  lifecycle {
    create_before_destroy = true
  }
}

# 프라이빗 보안그룹 http 인그리스 규칙
resource "aws_security_group_rule" "min-pri-http-ingress" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "TCP"
  source_security_group_id = aws_security_group.min-pub-sg.id
  security_group_id = aws_security_group.min-pri-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 프라이빗 보안그룹 https 인그리스 규칙
resource "aws_security_group_rule" "min-pri-https-ingress" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "TCP"
  source_security_group_id = aws_security_group.min-pub-sg.id
  security_group_id = aws_security_group.min-pri-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 프라이빗 보안그룹 ssh 인그리스 규칙
resource "aws_security_group_rule" "min-pri-ssh-ingress" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "TCP"
  source_security_group_id = aws_security_group.min-pub-sg.id
  security_group_id = aws_security_group.min-pri-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 프라이빗 보안그룹 egress 규칙
resource "aws_security_group_rule" "min-pri-egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.min-pri-sg.id
  lifecycle {
    create_before_destroy = true
  }
}

# 프라이빗 DB 보안그룹 rds 인그리스 규칙
resource "aws_security_group_rule" "min-pri-db-rds-ingress" {
  type = "ingress"
  from_port = 5432
  to_port = 5432
  protocol = "TCP"
  source_security_group_id = aws_security_group.min-pri-sg.id
  security_group_id = aws_security_group.min-pri-db-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 프라이빗 DB 보안그룹 docdb 인그리스 규칙
resource "aws_security_group_rule" "min-pri-db-dynamo-ingress" {
  type = "ingress"
  from_port = 27017
  to_port = 27017
  protocol = "TCP"
  source_security_group_id = aws_security_group.min-pri-sg.id
  security_group_id = aws_security_group.min-pri-db-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
# 프라이빗 DB 보안그룹 egress 규칙
resource "aws_security_group_rule" "min-pri-db-egress" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [ "0.0.0.0/0" ]
  security_group_id = aws_security_group.min-pri-db-sg.id
  lifecycle {
    create_before_destroy = true
  }
}
