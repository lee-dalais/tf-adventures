locals {
  prefix = "${var.app}-${var.env}-${var.region}"
}

#################################################
##### ECS #######################################
#################################################

resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.prefix}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "default" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_service" "default" {
  name            = "main-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2

  capacity_provider_strategy {
    base              = 1
    capacity_provider = "FARGATE"
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "web-app"
    container_port   = var.lb_port
  }

  network_configuration {
    subnets = data.aws_subnets.default.ids

    security_groups = [
      aws_security_group.ecs_cluster.id
    ]
    assign_public_ip = true
  }
}

resource "aws_ecs_task_definition" "web" {
  family                = "service"
  container_definitions = file("./task-definition.json")

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256

  execution_role_arn = aws_iam_role.task.arn
}

#################################################
##### ALB #######################################
#################################################

resource "aws_lb" "main" {
  name               = "${local.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = data.aws_subnets.default.ids

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${local.prefix}-alb"
  }
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.lb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.prefix}-lb-tg"
  port        = var.lb_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  tags = {
    Name = "${local.prefix}-lb-tg"
  }
}

#################################################
##### IAM #######################################
#################################################

resource "aws_iam_role" "task" {
  name = "${local.prefix}-task-role"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  inline_policy {
    name   = "inline-policy"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }
}

#################################################
##### SECURITY GROUPS ###########################
#################################################

resource "aws_security_group" "ecs_cluster" {
  name   = "${local.prefix}-sg-ecs"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description     = "ALB"
    from_port       = var.lb_port
    to_port         = var.lb_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb" {
  name   = "${local.prefix}-sg-alb"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = var.lb_port
    to_port     = var.lb_port
    protocol    = "tcp"
    cidr_blocks = [var.whitelist_cidr_block]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
