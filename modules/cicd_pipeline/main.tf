resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_role_policy" {
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
          "ecs:*",
          "codecommit:*",
          "logs:*",
          "s3:*"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_role_policy" {
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
          "codecommit:*",
          "codedeploy:*",
          "ecs:*",
          "ecr:*",
          "cloudwatch:*",
          "*"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}
resource "aws_s3_bucket" "cicd_bucket" {
  bucket = "nedal-cicd-artifact-bucket"
}


resource "aws_codepipeline" "main" {
  name     = "hello-world-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.cicd_bucket.id
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = var.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.codebuild.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      version          = "1"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      configuration = {
        ClusterName = var.cluster_name
        ServiceName = var.service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

# Codebuild project

resource "aws_codebuild_project" "codebuild" {
  depends_on = [
    aws_codecommit_repository.source_repo,
    aws_ecr_repository.image_repo
  ]
  name          = "codebuild-${var.source_repo_name}-${var.source_repo_branch}"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name = "REPOSITORY_URI"
      value = aws_ecr_repository.image_repo.repository_url
    }
    environment_variable {
      name = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name = "CONTAINER_NAME"
      value = var.family
    }
  }
  source {
    type = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2
phases:
  install:
    runtime-versions:
      docker: 18
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=$${COMMIT_HASH:=latest}         
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - printf '[{"name":"%s","imageUri":"%s"}]' "nedaltask" $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
artifacts:
    files: imagedefinitions.json
BUILDSPEC
  }
}        
# ---------------------------------------------------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecr_repository" "image_repo" {
  name                 = var.image_repo_name
  image_tag_mutability = "MUTABLE"

  #  image_scanning_configuration {
  #    scan_on_push = true
  #  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Code Commit
# ---------------------------------------------------------------------------------------------------------------------

# Code Commit repo

resource "aws_codecommit_repository" "source_repo" {
  repository_name = var.source_repo_name
  description     = "This is the app source repository"
}


# Trigger role and event rule to trigger pipeline

resource "aws_iam_role" "trigger_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "events.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  path               = "/"
}

resource "aws_iam_policy" "trigger_policy" {
  description = "Policy to allow rule to invoke pipeline"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "codepipeline:StartPipelineExecution"
      ],
      "Effect": "Allow",
      "Resource": "${aws_codepipeline.main.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "trigger-attach" {
  role       = aws_iam_role.trigger_role.name
  policy_arn = aws_iam_policy.trigger_policy.arn
}

resource "aws_cloudwatch_event_rule" "trigger_rule" {
  description   = "Trigger the pipeline on change to repo/branch"
  event_pattern = <<PATTERN
{
  "source": [ "aws.codecommit" ],
  "detail-type": [ "CodeCommit Repository State Change" ],
  "resources": [ "${aws_codecommit_repository.source_repo.arn}" ],
  "detail": {
    "event": [ "referenceCreated", "referenceUpdated" ],
    "referenceType": [ "branch" ],
    "referenceName": [ "${var.source_repo_branch}" ]
  }
}
PATTERN
  role_arn      = aws_iam_role.trigger_role.arn
  is_enabled    = true

}

resource "aws_cloudwatch_event_target" "target_pipeline" {
  rule      = aws_cloudwatch_event_rule.trigger_rule.name
  arn       = aws_codepipeline.main.arn
  role_arn  = aws_iam_role.trigger_role.arn
  target_id = "${var.source_repo_name}-${var.source_repo_branch}-pipeline"
}
########################################################################################  codecommit first push ###############################33333
resource "aws_iam_user" "pipeline_codecommit_user" {
  name = "codecommit_user"
}

resource "aws_iam_policy" "codecommit_pullpush_policy" {
  name        = "codecommit_pullpush"
  path        = "/"
  description = "CodeCommit policy for the pipeline_codecommit_user used by a CI/CD pipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "codecommit:GitPull",
          "codecommit:GitPush"
        ]
        Effect   = "Allow"
        Resource =aws_codecommit_repository.source_repo.arn
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "codecommit_policy_attachment" {
  user       = aws_iam_user.pipeline_codecommit_user.name
  policy_arn = aws_iam_policy.codecommit_pullpush_policy.arn
}


resource "aws_iam_access_key" "pipeline_codecommit_user" {
  user = aws_iam_user.pipeline_codecommit_user.name
}



