provider "aws" {

  region = "us-west-2"

}


resource "aws_vpc" "main_vpc" {

  cidr_block = "10.0.0.0/16"

  enable_dns_support = true

  enable_dns_hostnames = true

}


resource "aws_subnet" "main_subnet" {

  vpc_id     = aws_vpc.main_vpc.id

  cidr_block = "10.0.1.0/24"

}


resource "aws_security_group" "ecs_sg" {

  vpc_id = aws_vpc.main_vpc.id


  ingress {

    from_port   = 80

    to_port     = 80

    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }


  egress {

    from_port   = 0

    to_port     = 0

    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]

  }

}


resource "aws_iam_role" "ecs_task_execution_role" {

  name = "ecsTaskExecutionRole"


  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [{

      Action = "sts:AssumeRole"

      Effect = "Allow"

      Principal = {

        Service = "ecs-tasks.amazonaws.com"

      }

    }]

  })


  managed_policy_arns = [

    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",

  ]

}


resource "aws_ecs_cluster" "medusa_cluster" {

  name = "medusa-cluster"

}


resource "aws_ecs_task_definition" "medusa_task" {

  family                   = "medusa"

  network_mode             = "awsvpc"

  requires_compatibilities = ["FARGATE"]

  cpu                      = "512"

  memory                   = "1024"


  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn


  container_definitions = jsonencode([{

    name  = "medusa-container"

    image = "medusajs/medusa:latest"

    essential = true

    portMappings = [{

      containerPort = 80

      hostPort      = 80

    }]

  }])

}


resource "aws_ecs_service" "medusa_service" {

  name            = "medusa-service"

  cluster         = aws_ecs_cluster.medusa_cluster.id

  task_definition = aws_ecs_task_definition.medusa_task.arn

  desired_count   = 1

  launch_type     = "FARGATE"


  network_configuration {

    subnets         = [aws_subnet.main_subnet.id]

    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}