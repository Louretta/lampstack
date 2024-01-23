locals {
  name  = "my-wordpress-app"
  media_bucket ="my-wordpress-media-bucket"
  code_bucket ="my_wordpress-code-bucket"
  log_bucket ="my-wordpress-log-bucket"
  s3_origin_id = "my-wordpress-s3-origin"
  emails = ["louretta.eyina@cloudhight.com"]
}

#create vpc 
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags ={
    name= "${local.name}-vpc"
  }
}
#create public subnet 1
resource "aws_subnet" "pubsn1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "${local.name}-pubsn1"
  }
}

#Create public subnet 2
resource "aws_subnet" "pubsn2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "${local.name}-pubsn2"
  }
}

#Create private subnet 1
resource "aws_subnet" "privsn1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "${local.name}-privsn1"
  }
}


#Create private subnet 2
resource "aws_subnet" "privsn2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "${local.name}-privsn2"
  }
}

#create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${locals-name}-igw"
  }
}

#create natgateway 
resource "aws_nat_gateway" "natgateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pubsn1.id
  depends_on =[aws_internet_gateway.igw]

  tags = {
    Name = "${locals-name}-natgateway"
  }

}

#create elstic ip 
resource "aws_eip" "eip" {
  domain   = "vpc"
  depends_on = [aws_internet_gateway  ]
}

#Create route table for public subnet 
resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.name}-pubrt"
  }
}

#create route table for private route table 
resource "aws_route_table" "privrt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgateway.id
  }

  tags = {
    Name = "${local.name}-privrt"
  }
}

#Create route table association for public subnet
resource "aws_route_table_association" "rtpub1" {
  subnet_id      = aws_subnet.pubsn1.id
  route_table_id = aws_route_table.pubrt.id
}
resource "aws_route_table_association" "rtpub2" {
  subnet_id      = aws_subnet.pubsn2.id
  route_table_id = aws_route_table.pubrt.id
}

#cerate frontend security group 
resource "aws_security_group" "frontend-sg" {
  name        = "${local-name}-frontend-sg"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "open HTTP port"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  } 

  ingress {
    description      = "open SSH port"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local-name}-frontend-sg"
  }
}

#create backend security group 
resource "aws_security_group" "backend-sg" {
  name        = "${local-name}-backend-sg"
  description = "Allow MYSQL inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "MYSQL port"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups = [aws_security_group.frontend-sg.id]
  } 


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local-name}-backend-sg"
  }
}

#create Bucket media 
resource "aws_s3_bucket" "media" {
  bucket = local.media_bucket

  tags = {
    Name   = "${local.media_bucket}"
  }
}

#create aws bucket ownership controls 
resource "aws_s3_bucket_ownership_controls" "s3-bucket" {
  bucket = aws_s3_bucket.media.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#create s3 bucket public access 
resource "aws_s3_bucket_public_access_block" "pub-media_bucket" {
  bucket = aws_s3_bucket.media.id

  block_public_acls       = false 
  block_public_policy     = false 
  ignore_public_acls      = false
  restrict_public_buckets = false 

}

#create media bucket policy 
resource "aws_s3_bucket_policy" "media" {
  depends_on = [aws_s3_bucket.acess-list-media ]
  bucket = aws_s3_bucket.media.id
  policy=jsonencode({
    id = "media"
    statement = [
      {
        Action = [
          "s3:*"
        ]
        Effect = "Allow"
        Principal = {
          aws = "*"
        }
        resource = ["${aws_s3_bucket.media.arn}/*"]
        sid = "publicReadGetobject"
      }

    ]
    version = "2012-10-17"
  })
}

#create s3 code bucket
resource "aws_s3_bucket" "code" {
  bucket = local.code_bucket
  force_destroy = true
  tags = {
    Name = "${local.code_bucket}"
  }
  
}

#create s3 ownership controls for code bucket 
resource "aws_s3_bucket_ownership_controls" "code_bucket" {
  bucket = aws_s3_bucket.code.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
#create s3 bucket acl for code bucket 
resource "aws_s3_bucket_acl" "code_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.code_bucket]

  bucket = aws_s3_bucket.code.id
  acl    = "private"
}


#create s3 log bucket 
resource "aws_s3_bucket" "log" {
  bucket = local.log_bucket
  force_destroy = true
  tags = {
    Name = "${local.log_bucket}"
  }
}

#create ownership cpntrol for log bucket 
resource "aws_s3_bucket_ownership_controls" "log" {
  bucket = aws_s3_bucket.log.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

#create public access for s3 log bucket 
resource "aws_s3_bucket_public_access_block" "pub-log" {
  bucket = aws_s3_bucket.log .id
  block_public_acls       = false 
  block_public_policy     = false 
  ignore_public_acls      = false
  restrict_public_buckets = false 

}
#create s3 acl for log bucket 
resource "aws_s3_bucket_acl" "log_acl" {
  bucket =[aws_s3_bucket.log_bucket.id]
  acl    = "public-read"
}

#create log bucket policy 
resource "aws_s3_bucket_policy" "log" {
  depends_on = [aws_s3_bucket.acess-list-log ]
  bucket = aws_s3_bucket.log.id
  policy=jsonencode({
    id = "log"
    statement = [
      {
        Action = [
          "s3:*"
        ]
        Effect = "Allow"
        Principal = {
          aws = "*"
        }
        resource = ["${aws_s3_bucket.media.arn}/*"]
        sid = "publicReadGetobject"
      }

    ]
    version = "2012-10-17"
  })
}

#create database subnet group 
resource "aws_db_subnet_group" "db-sunbet-group" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = [aws_subnet.privsn1, aws_subnet.privsn2]

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

#create Database 
resource "aws_db_instance" "database-instance" {
  allocated_storage    = 20
  db_subnet_group_name = aws_db_subnet_group.db-sunbet-group
  db_name              = var.db_name
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  identifier           = "dbo1"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  port                 = 3306
  #multi_az = true
  vpc_security_group_ids = [aws_security_group.backend-sg]
  apply_immediately = true
  skip_final_snapshot = true
  tags = {
    name = "${local.name}-db-instance"
  }
}

#create wordpress webserver
resource "aws_instance" "wordpress-server" {
  ami                         = var.webserver-ami
  instance_type               =var.webserver-instance-instance_type
  vpc_security_group_ids      = [aws_security_group.frontend-sg.id]
  subnet_id                   =aws_subnet.pubsn1.id
  iam_instance_profile        = aws_iam_instance_profile.iam_instance_profile
  key_name                    =aws_key_pair.keypair
  associate_public_ip_address = true
  user_data                   = templatefile("./user-data/wp.sh",{
    db_endpoint               =aws_db_instance.db-instance.db_endpoint,
  }
   
}