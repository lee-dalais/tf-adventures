provider "aws" {
  region  = "us-west-2"
  profile = "default" // AWS CLI profile

  default_tags {
    tags = {
      Owner = "User"
    }
  }
}

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}