resource "aws_iam_role" "webserver" {
  name_prefix = "${var.namespace}-webserver-"
  description = "IAM role for web server instances"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.namespace}-webserver-role"
  }
}

# Inline policy that grants CW Logs and RDS permissions
resource "aws_iam_role_policy" "webserver" {
  name_prefix = "${var.namespace}-webserver-policy-"
  role        = aws_iam_role.webserver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:*"]
      Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["rds:*"]
        Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "webserver" {
  name_prefix = "${var.namespace}-webserver-profile-"
  role        = aws_iam_role.webserver.name

  tags = {
    Name = "${var.namespace}-webserver-profile"
  }
}

// this feeds user_data into aws_launch_template below
data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    // content for the cloud init configuration comes from a template file
    content = templatefile("${path.module}/cloud_config.yaml", var.db_config)
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] // Canonical
}

// allows for multiple versions of a launch template configuration
resource "aws_launch_template" "webserver" {
  name_prefix   = var.namespace
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data     = data.cloudinit_config.config.rendered
  key_name      = var.ssh_keypair
  iam_instance_profile {
    name = aws_iam_instance_profile.webserver.name
  }
  vpc_security_group_ids = [var.sg.websvr]
}

resource "aws_autoscaling_group" "webserver" {
  name                = "${var.namespace}-asg"
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = var.vpc.private_subnets
  target_group_arns   = [for tg in module.alb.target_groups : tg.arn]
  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }
}

module "alb" {
  // creates AWS Application/Network Load Balancer
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 9.9.0"
  name               = var.namespace
  load_balancer_type = "application"
  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]
  enable_deletion_protection = false  # Allow easy cleanup for learning environment
  listeners = {
    ex-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ex-instance"
      }
    }
  }
  target_groups = {
    ex-instance = {
      name_prefix        = "websvr"
      protocol           = "HTTP"
      port               = 8080
      target_type        = "instance"
      create_attachment  = false  # ASG handles attachment via target_group_arns
    }
  }
}
