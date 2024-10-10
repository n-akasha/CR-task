output "pipeline_id" {
  value = aws_codepipeline.main.id
}

output "image_repo_url" {
  value = aws_ecr_repository.image_repo.repository_url
}

output "image_repo_arn" {
  value = aws_ecr_repository.image_repo.arn
}
output "source_repo_clone_url_http" {
  value = aws_codecommit_repository.source_repo.clone_url_http
}
