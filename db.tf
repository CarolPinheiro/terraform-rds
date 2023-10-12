# configured aws provider with proper credentials
provider "aws" {
  region  = "us-east-1"
  profile = "default" // profile configurado na CLI, pra ele saber qual usar
}




# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "default vpc"
  }
}




# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}




# create a default subnet in the first az if one does not exit
resource "aws_default_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]
}


# create a default subnet in the second az if one does not exit
resource "aws_default_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.available_zones.names[1]
}


data "aws_security_group" "lambda_security_group" {
  name = "lambda security group"
}


# create security group for the database
resource "aws_security_group" "database_security_group" {
  name        = "database security group"
  description = "enable postgress access on port 5432"
  vpc_id      = aws_default_vpc.default_vpc.id


  ingress {
    description      = "mysql/aurora access"
    from_port        = 5432
    to_port          = 5432
    protocol         = "TCP"
    security_groups  = [data.aws_security_group.lambda_security_group.id]
  }


  egress {
    description      = "mysql/aurora access"
    from_port        = 5432
    to_port          = 5432
    protocol         = "TCP"
    security_groups  = [data.aws_security_group.lambda_security_group.id]
  }


  tags   = {
    Name = "database security group"
  }
}




# create the subnet group for the rds instance, specify which subnets we're going to use to our db
resource "aws_db_subnet_group" "database_subnet_group" {
  name         = "dabatase-subnets"
  subnet_ids   = [aws_default_subnet.subnet_az1.id, aws_default_subnet.subnet_az2.id]
  description  = "subnets for database instance"


  tags   = {
    Name = "dabatase-subnets"
  }
}


data "aws_ssm_parameter" "username" {
  name = "database-username"
}
data "aws_ssm_parameter" "password" {
  name = "database-password"
}


# create the rds instance
resource "aws_db_instance" "db_instance" {
  engine                  = "postgres"
  engine_version          = "15"
  multi_az                = false
  identifier              = "dev-rds-instance"
  username                = data.aws_ssm_parameter.username.value
  password                = data.aws_ssm_parameter.password.value
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_subnet_group_name    = aws_db_subnet_group.database_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.database_security_group.id]
  availability_zone       = data.aws_availability_zones.available_zones.names[0]
  db_name                 = "clients"
  skip_final_snapshot     = true
  publicly_accessible     = true
}
