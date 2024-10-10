# Cloudride - Technical Challenge
terraform-Docker-ecs-cicd





![image](https://user-images.githubusercontent.com/100461037/173172327-187f4083-160c-4695-9425-00669d177f60.png)
1. Create an automation that will deploy AWS infrastructure that will include the following items: 

VPC with Internet Gateway and Internet access
4 Subnets - 2 public subnets & 2 private subnets
Public subnets - internet access via the Internet Gateway
Private subnets - internet access via NAT Gateway
Regions, CIDR ranges, tags and anything that is not mentioned is at your full discretion.

You may use any automation framework you prefer.

 

2. Deploying a simple “Hello World” container on an ECS cluster

You should deploy it with:

Service Autoscaling - with at least 2 running tasks (containers)
Application Load Balancer - Internet access
Tasks (Containers) - On private subnets
Keep in mind, the application should be exposed to the Internet with the application load balancer (ALB) only.

3. Create a CD pipeline that will automatically be rolling update the "Hello World" application with the new changes. 

Create a CD pipeline with a CodeBuild and CodePipeline that will connect to the repository where the code stores and push the changes you made to a new container deployment (docker image) on ECS.

this terraform script contains 4 modules that do the following 
- vpc module  :   	     creates a vpc
			     creates 2 private and 2 public subnets
			     creates an internet gateway to connect the VPC to the internet
			     creates  NAT gateways for the private subnets 
                 creates  security groups and  route tables 

ecs_cluster module     creates ecs cluster to run 2 tasks of fargate from
                       the docker image on ECR repositories.

cicd_pipeline module   creates CI/CD pipeline to build the application

alb module             creates the application load balancer for the ecs tasks

All you need to do is --- enter the credentials for your aws account with aws configure  .

And apply.

After the terraform apply is done .

You need to push the docker file needed to the CodeCommit  repository 



and the pipeline is triggered and started.
![image](https://user-images.githubusercontent.com/100461037/173172340-f11305b5-66d0-4055-af36-eaeec5c7b181.png)


then copy the alb dns name from the terraform output to your brouser 



 
