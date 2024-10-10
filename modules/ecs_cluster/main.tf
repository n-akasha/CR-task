##########################################################################################
# IAM ecsTaskExecutionRoles 
##########################################################################################
resource "aws_iam_role" "ecsTaskExecutionRole" {
    name                  = "test-app-ecsTaskExecutionRole"
    assume_role_policy    = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions               = ["sts:AssumeRole"]

    principals {
      type                = "Service"
      identifiers         = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
    role                  = aws_iam_role.ecsTaskExecutionRole.name
    policy_arn            = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecsTaskRole" {
    name                  = "ecsTaskRole"
    assume_role_policy    = data.aws_iam_policy_document.assume_role_policy.json   
}

resource "aws_iam_role_policy_attachment" "ecsTaskRole_policy" {
    role                  = aws_iam_role.ecsTaskRole.name
    policy_arn            = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
##########################################################################################
# security groups 
##########################################################################################
# ------------------------------------------------------------------------------
# Security Group for ECS app
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs_sg" {
    vpc_id                      = var.vpc_id
    name                        = "nedaltask-sg-ecs"
    description                 = "Security group for ecs app"
    revoke_rules_on_delete      = true
}
# ------------------------------------------------------------------------------
# ECS app Security Group Rules - INBOUND
# ------------------------------------------------------------------------------
resource "aws_security_group_rule" "ecs_alb_ingress" {
    type                        = "ingress"
    from_port                   = 0
    to_port                     = 0
    protocol                    = "-1"
    description                 = "Allow inbound traffic from ALB"
    security_group_id           = aws_security_group.ecs_sg.id
    source_security_group_id    = var.alb_security_group_id
}
# ------------------------------------------------------------------------------
# ECS app Security Group Rules - OUTBOUND
# ------------------------------------------------------------------------------
resource "aws_security_group_rule" "ecs_all_egress" {
    type                        = "egress"
    from_port                   = 0
    to_port                     = 0
    protocol                    = "-1"
    description                 = "Allow outbound traffic from ECS"
    security_group_id           = aws_security_group.ecs_sg.id
    cidr_blocks                 = ["0.0.0.0/0"] 
}




#ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
    name                                = "nedal-ecs-cluster"
}

#The Task Definition used in conjunction with the ECS service
resource "aws_ecs_task_definition" "task_definition" {
    family                              = "test-family"
    # container definitions describes the configurations for the task
    container_definitions               = jsonencode(
    [
    {
        "name"                          : "nedaltask",
        "image"                         : "${var.image_repo_url}:latest",
        "entryPoint"                    : []
        "essential"                     : true,
        "networkMode"                   : "awsvpc",
        "portMappings"                  : [
                                            {
                                                "containerPort" : 80,
                                                "hostPort"      : 80,
                                            }
                                          ]
        "healthCheck"                   : {
                                            "command"     : [ "CMD-SHELL", "curl -f http://localhost:80/ || exit 1" ],
                                            "interval"    : 30,
                                            "timeout"     : 5,
                                            "startPeriod" : 10,
                                            "retries"     :3
                                          }
    }
    ] 
    )
    #Fargate is used as opposed to EC2, so we do not need to manage the EC2 instances. Fargate is serveless
    requires_compatibilities            = ["FARGATE"]
    network_mode                        = "awsvpc"
    cpu                                 = "256"
    memory                              = "512"
    execution_role_arn                  = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn                       = aws_iam_role.ecsTaskRole.arn
}

#The ECS service described. This resources allows you to manage tasks
resource "aws_ecs_service" "ecs_service" {
    name                                = "hello-world-service"
    cluster                             = aws_ecs_cluster.ecs_cluster.arn
    task_definition                     = aws_ecs_task_definition.task_definition.arn
    launch_type                         = "FARGATE"
    scheduling_strategy                 = "REPLICA"
    desired_count                       = 2 # the number of tasks you wish to run

  network_configuration {
    subnets                             = var.private_subnets
    assign_public_ip                    = false
    security_groups                     = [aws_security_group.ecs_sg.id, var.alb_security_group_id]
  }

# This block registers the tasks to a target group of the loadbalancer.
  load_balancer {
    target_group_arn                    = var.target_group_arn
    container_name                      = "nedaltask"
    container_port                      = 80
  }
  
}