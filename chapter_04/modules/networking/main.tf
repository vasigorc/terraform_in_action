data "aws_availability_zones" "available" {}

module "vpc" {
  source                       = "terraform-aws-modules/vpc/aws"
  version                      = "5.7.1"
  name                         = "${var.namespace}-vpc"
  cidr                         = "10.0.0.0/16"
  azs                          = data.aws_availability_zones.available.names
  private_subnets              = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets               = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets             = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  create_database_subnet_group = true
  enable_nat_gateway           = true
  # For production multi-AZ high availability, set single_nat_gateway = false (creates one NAT per AZ, ~$97/mo)
  # For learning/cost savings, use single NAT gateway (~$32/mo)
  single_nat_gateway           = true
}

resource "aws_security_group" "lb" {
  name_prefix = "${var.namespace}-lb-"
  description = "Security group for load balancer"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.namespace}-lb-sg"
  }
}

resource "aws_security_group_rule" "lb_http_ingress" {
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "lb_egress" {
  type              = "egress"
  description       = "Allow all outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group" "websvr" {
  name_prefix = "${var.namespace}-websvr-"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.namespace}-websvr-sg"
  }
}

resource "aws_security_group_rule" "websvr_http_from_lb" {
  type                     = "ingress"
  description              = "HTTP from load balancer"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb.id
  security_group_id        = aws_security_group.websvr.id
}

resource "aws_security_group_rule" "websvr_ssh_from_vpc" {
  type              = "ingress"
  description       = "SSH from within VPC"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.websvr.id
}

resource "aws_security_group_rule" "websvr_egress" {
  type              = "egress"
  description       = "Allow all outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.websvr.id
}


resource "aws_security_group" "db" {
  name_prefix = "${var.namespace}-db-"
  description = "Security group for database"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.namespace}-db-sg"
  }
}

resource "aws_security_group_rule" "db_mysql_from_websvr" {
  type                     = "ingress"
  description              = "MySQL from web servers"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.websvr.id
  security_group_id        = aws_security_group.db.id
}

resource "aws_security_group_rule" "db_egress" {
  type              = "egress"
  description       = "Allow all outbound"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db.id
}
