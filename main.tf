provider "aws" {
  region = "eu-central-1"
}

### setup VPC

# Initialize availability zone data from AWS
data "aws_availability_zones" "available" {}

# Vpc resource
resource "aws_vpc" "myVpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "myVpc"
  }
}

# Internet gateway for the public subnets
resource "aws_internet_gateway" "myInternetGateway" {
  vpc_id = "${aws_vpc.myVpc.id}"

  tags {
    Name = "myInternetGateway"
  }
}

# Subnet (public) for every available zone
resource "aws_subnet" "public_subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.myVpc.id}"
  cidr_block              = "10.20.${10+count.index}.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags {
    Name = "PublicSubnet"
  }
}

# Subnet (private) for every available zone
resource "aws_subnet" "private_subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.myVpc.id}"
  cidr_block              = "10.20.${20+count.index}.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = false

  tags {
    Name = "PrivateSubnet"
  }
}

# Routing table for public subnets
resource "aws_route_table" "rtblPublic" {
  vpc_id = "${aws_vpc.myVpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.myInternetGateway.id}"
  }

  tags {
    Name = "rtblPublic"
  }
}

resource "aws_route_table_association" "route" {
  count          = "${length(data.aws_availability_zones.available.names)}"
  subnet_id      = "${element(aws_subnet.public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtblPublic.id}"
}

# Elastic IP for NAT gateway
resource "aws_eip" "nat" {
  vpc = true
}

# NAT Gateway
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${element(aws_subnet.private_subnet.*.id, 1)}"
  depends_on    = ["aws_internet_gateway.myInternetGateway"]
}

# Routing table for private subnets
resource "aws_route_table" "rtblPrivate" {
  vpc_id = "${aws_vpc.myVpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat-gw.id}"
  }

  tags {
    Name = "rtblPrivate"
  }
}

resource "aws_route_table_association" "private_route" {
  count          = "${length(data.aws_availability_zones.available.names)}"
  subnet_id      = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtblPrivate.id}"
}

### setup security group
resource "aws_security_group" "vpc_lambda" {
  name        = "calculator-vpc-lambda"
  description = "Allow outbound traffic for vpc-lambda"
  vpc_id      = "${aws_vpc.myVpc.id}"

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "calculator-dev"
    Project     = "calculator.io"
    Environment = "dev"
  }
}

### setup IAM policy
resource "aws_iam_policy" "iam_policy_for_lambda" {

    name         = "aws_iam_policy_for_terraform_aws_lambda_role"
    path         = "/"
    description  = "AWS IAM Policy for managing aws lambda role"
    policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect": "Allow"
    }
    ]
    }
    EOF
}

### setup IAM role 
resource "aws_iam_role" "lambda_role" {
    name   = "Test_Lambda_Function_Role"
    assume_role_policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
        "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
    }
    ]
    }
    EOF
    managed_policy_arns = [
        aws_iam_policy.iam_policy_for_lambda.arn,
        "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
        "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    ]
}

### Zip function project
data "archive_file" "zip_the_function_code" {
  type        = "zip"
  source_dir  = "${path.module}/Calculator/"
  output_path = "${path.module}/Calculator/calculator.zip"
}

### Get all private subnets
data "aws_subnets" "private_subnets" {

  filter {
    name   = "vpc-id"
    values = ["${aws_vpc.myVpc.id}"]
  }

  tags = {
    Name = "PrivateSubnet"
  }
}

### setup lambda function
resource "aws_lambda_function" "calculator_lambda_func" {
  filename                       = data.archive_file.zip_the_function_code.output_path
  function_name                  = "Calculator_Lambda_Function"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "index.lambda_handler"
  runtime                        = "dotnet6"

  vpc_config {
    security_group_ids = [aws_security_group.vpc_lambda.id]
    subnet_ids         = data.aws_subnets.private_subnets.ids
  }
}