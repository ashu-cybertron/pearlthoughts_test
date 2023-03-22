provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "test-vpc"
  }
}

resource "aws_subnet" "public" {
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  vpc_id            = aws_vpc.test_vpc.id
  tags = {
    Name = "test-public-subnet"
  }
}

resource "aws_subnet" "private" {
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  vpc_id            = aws_vpc.test_vpc.id

  tags = {
    Name = "test-private-subnet"
  }
}


resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution.name
}

resource "aws_ecr_repository" "test_ecr_repo" {
  name = "test-ecr-repo"
}

resource "aws_ecs_task_definition" "test_task_definition" {
  family                   = "test-task"
  container_definitions    = file("${path.module}/container-definition.json")
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
}

resource "aws_ecs_service" "test_service" {
  name            = "test-service"
  cluster         = aws_ecs_cluster.test_cluster.id
  task_definition = aws_ecs_task_definition.test_task_definition.arn
  desired_count   = 1

  network_configuration {
    security_groups = [aws_security_group.test_security_group.id]
    subnets         = aws_subnet.private.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.test_target_group.arn
    container_name   = "test-container"
    container_port   = 3000
  }
}

resource "aws_ecs_cluster" "test_cluster" {
  name = "test-cluster"
}

resource "aws_security_group" "test_security_group" {
  name_prefix = "test-sg"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "test_lb" {
  name               = "test-lb"
  internal           = false
  load_balancer_type = "application"

  subnet_mapping {
    subnet_id = aws_subnet.public.id
  }

  tags = {
    Name = "test-lb"
  }
}


resource "aws_lb_target_group" "test_target_group" {
  name_prefix = "testtg"

  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  depends_on = [
    aws_lb.test_lb,
  ]
}

resource "aws_lb_listener" "test_listener" {
  load_balancer_arn = aws_lb.test_lb.arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.test_target_group.arn
    type             = "forward"
  }
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.test_task_definition.arn
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "ECR_REGISTRY" {
  value = aws_ecr_repository.test_ecr_repo.registry_id
}

output "ECR_REPOSITORY" {
  value = aws_ecr_repository.test_ecr_repo.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.test_ecr_repo.repository_url
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.test_task_definition.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.test_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.test_service.name
}

output "lb_dns_name" {
  value = aws_lb.test_lb.dns_name
}