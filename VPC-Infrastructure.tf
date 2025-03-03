provider "aws" {
  region     = "us-west-2"
  access_key = "#####################"
  secret_key = "####################################"
}

terraform {
  backend "s3" {
    bucket = "cloud-tfstate1"
    key    = "cloud/tfstate"
  region     = "us-west-2"
  access_key = "AKIAXTORHGJHGPGTL43LZJQ6V"
  secret_key = "jjFS1GGfhIggbhjvxdjuJy8Hinwknys+h4LHE9qyIXvl"
  dynamodb_table = "cloud-dynamodb"
  }
}

resource "aws_vpc" "custom-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "custom-vpc"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.custom-vpc.id
  cidr_block = "10.0.100.0/24"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.custom-vpc.id
  cidr_block = "10.0.200.0/24"

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_security_group" "custom-securitygroup" {
  name        = "custom-securitygroup"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.custom-vpc.id

  tags = {
    Name = "custom-securitygroup"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.custom-securitygroup.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.custom-securitygroup.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom-vpc.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public-subnet-associate" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDBHSfhI0AknpcNmRJrr/MWi4ZdGtprBWPm7Z1poIG5r2lvQ/fEXpfiVwV+1aE1Yfej+d8YR0Jf9KuoG5C5RHx+bK9BTZp+c6D6nHD+iXFCIF341awQ7bR8hTRz70Jv9/bL0ozkTo6l0OJ/DU2SR/lwKTKG9hTm0SKVNqTWwKBACsoMU7145aWSoOvtzLLYKWaiQNj3I12mpiN67VzB69hEtgw6qZPLA7fz+4DpkKnXOfQX+Wld6U/eEXryU/apiSLhfta8oYPXgX4g7HIp/GAKDz/qD6trsqe8PhHW4E23HlNWgU2JWcO6Pm9u9MW7Ye+/3dSa8+Id0H02RI5ZsnHHMz0eq9GPtZgbJkthMQ2OApWUCbeFb8estzFpclFLqHvE7BJ9KREsXGHIt7BViIk4OpZ4Gc7A4rqtX0cBzSNUAUOaNNEC9/FLi+BFRNjGC9XbuZYmAIHcCRqgJlrINZqnKAA27slRpxu/+xN6Xx0P3ar+3LmR0XBrfJfMQ7RYJLE= root@ip-172-31-36-48.ap-south-1.compute.internal"
}

resource "aws_instance" "ec2-pub" {
  ami           = "ami-09245d5773578a1d6"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public-subnet.id
  key_name      = "deployer-key" 
  security_groups = [aws_security_group.custom-securitygroup.id]
 
  tags = {
    Name = "ec2-pub-instance"
  }
}

resource "aws_eip" "public-ip-assign" {
  instance = aws_instance.ec2-pub.id
  domain   = "vpc"
}

resource "aws_instance" "ec2-DB" {
  ami           = "ami-09245d5773578a1d6"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private-subnet.id
  key_name      = "deployer-key"
  security_groups = [aws_security_group.custom-securitygroup.id]

  tags = {
    Name = "ec2-pri-instance"
  }
}

resource "aws_eip" "netgateway-ip-assign" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "netgateway" {
  allocation_id = aws_eip.netgateway-ip-assign.id
  subnet_id     = aws_subnet.public-subnet.id

  tags = {
    Name = "netgateway"
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.custom-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.netgateway.id
  }

  tags = {
    Name = "private-rt"
  }
}  

resource "aws_route_table_association" "private-subnet-associate" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-rt.id
}
