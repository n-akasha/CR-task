#output "ecs_cluster_id" {
#  value = aws_ecs_cluster.main.id
#}
output "ecs_task_def_arn" {
  value = aws_ecs_task_definition.task_definition.arn
}
output "cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}
