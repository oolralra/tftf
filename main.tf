provider "aws" {
  region = "ap-northeast-2"
}

module "min-vpc" {
    source = "./vpc"
}

module "min-eks" {
    source = "./eks"
    min-vpc-id = module.min-vpc.min-vpc-id
    pri-sub1-id = module.min-vpc.pri-sub1-id
    pri-sub2-id = module.min-vpc.pri-sub2-id
    pub-sub1-id = module.min-vpc.pub-sub1-id
    pub-sub2-id = module.min-vpc.pub-sub2-id

}