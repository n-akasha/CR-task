provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "nedaltask"
    }
  }
}
# Call the VPC Module
module "vpc" {
  source = "./modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Call the ECS Cluster Module
module "ecs_cluster" {
  source           = "./modules/ecs_cluster"
  vpc_id           = module.vpc.vpc_id
  private_subnets  = module.vpc.private_subnets
  cluster_name     = "my-cluster"
  target_group_arn = module.alb.target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  image_repo_url   = module.cicd_pipeline.image_repo_url
}

# Call the ALB Module
module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnets
  target_group_name = "ecs-target-group"
}

# Call the CI/CD Module
module "cicd_pipeline" {
  source          = "./modules/cicd_pipeline"
  cluster_name  = module.ecs_cluster.cluster_name
  service_name    = "hello-world-service"
  ecs_task_def    = module.ecs_cluster.ecs_task_def_arn
  repository_name = "nedaltask"
  build_project   = "hello-world-build"
}
