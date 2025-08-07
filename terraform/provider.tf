terraform {
  backend "s3" {
    bucket = "nifitest123456789"
    key = "dev/nifi/terraform.tfstate"
    region = "us-west-1"
  }
}

provider "aws" {
  region = "us-west-1"
}