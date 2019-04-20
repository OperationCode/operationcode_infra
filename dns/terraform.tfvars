terragrunt = {
  remote_state {
    backend = "s3"
    config {
      bucket         = "operationcode-infra-config"
      key            = "operationcode_infra/dns/${path_relative_to_include()}/terraform.tfstate"
      region         = "us-east-2"
      encrypt        = true
      dynamodb_table = "opcode-terraform-lock"
    }
  }
}