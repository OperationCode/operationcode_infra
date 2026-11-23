# GitHub Actions roles that push images to ECR, one per repo.
# Each role trusts only that repo's two GitHub environment subjects (immutable OIDC subject format).
# The old shared role GitHubActions-ECR-Push is not managed here; it is deleted once by CLI.

# The OIDC provider exists in AWS and is not managed by Terraform.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_ecr_push = {
    "back-end" = {
      repo_name   = "back-end"
      github_ref  = "OperationCode@10479364/back-end@182584277"
      github_repo = "OperationCode/back-end"
    }
    "pybot" = {
      repo_name   = "pybot"
      github_ref  = "OperationCode@10479364/operationcode-pybot@146210805"
      github_repo = "OperationCode/operationcode-pybot"
    }
  }
}

data "aws_ecr_repository" "github_ecr_push" {
  for_each = local.github_ecr_push
  name     = each.value.repo_name
}

resource "aws_iam_role" "github_ecr_push" {
  for_each = local.github_ecr_push

  name                 = "GitHubActions-ECR-Push-${each.key}"
  description          = "GitHub Actions ${each.value.github_repo}: push to ECR repository ${each.value.repo_name}"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = [
            "repo:${each.value.github_ref}:environment:ecr-main",
            "repo:${each.value.github_ref}:environment:ecr-approval",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_ecr_push" {
  for_each = local.github_ecr_push

  name = "ecr-push-${each.key}"
  role = aws_iam_role.github_ecr_push[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = data.aws_ecr_repository.github_ecr_push[each.key].arn
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*" # cannot be limited to a repository
      },
    ]
  })
}

output "github_ecr_push_role_arns" {
  value = { for k, r in aws_iam_role.github_ecr_push : k => r.arn }
}
