#################################################
##### ECR #######################################
#################################################

resource "aws_ecr_repository" "main" {
  name                 = "ecs-primary"
  image_tag_mutability = "IMMUTABLE"
}