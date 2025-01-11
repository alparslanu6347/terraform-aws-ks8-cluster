provider "aws" {
  region  = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "name" {   // It will create the resources within the default VPC
  default = true          // If you want, replace with your specific VPC ID  ===>>>   id = "vpc-xxxxxxxx"
}

locals {
  name = "arrow"         // If you want change here, optional
}


resource "aws_iam_instance_profile" "ec2connectprofile" {
  name = "ec2connectprofile-${local.name}"
  role = aws_iam_role.ec2connectcli.name
}


resource "aws_iam_role" "ec2connectcli" {
  name               = "ec2connectcli-${local.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "my_inline_policy" {
  name   = "my_inline_policy"
  role   = aws_iam_role.ec2connectcli.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : "ec2-instance-connect:SendSSHPublicKey",
        "Resource" : "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
        "Condition" : {
          "StringEquals" : {
            "ec2:osuser" : "ubuntu"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : "ec2:DescribeInstances",
        "Resource" : "*"
      }
    ]
  })
}


resource "aws_security_group" "mutual-sg" {
  name   = var.sec-gr-mutual
  vpc_id = data.aws_vpc.name.id 

  ingress {
    protocol  = "tcp"
    from_port = 10250
    to_port   = 10250
    self      = true
  }

    ingress {
    protocol  = "udp"
    from_port = 8472
    to_port   = 8472
    self      = true
  }

    ingress {
    protocol  = "tcp"
    from_port = 2379
    to_port   = 2380
    self      = true
  }

}

resource "aws_security_group" "worker-sg" {
  name   = var.sec-gr-k8s-worker
  vpc_id = data.aws_vpc.name.id


  ingress {
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["${var.allowed_ip}"]
  }

  egress{
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "worker-secgroup"
  }
}

resource "aws_security_group" "master-sg" {
  name = var.sec-gr-k8s-master
  vpc_id = data.aws_vpc.name.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["${var.allowed_ip}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol  = "tcp"
    from_port = 10257
    to_port   = 10257
    self      = true
  }

  ingress {
    protocol  = "tcp"
    from_port = 10259
    to_port   = 10259
    self      = true
  }

  ingress {
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "master-secgroup"
  }
}

resource "aws_security_group_rule" "worker_to_master" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [format("%s/32", aws_instance.master.private_ip)]
  security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "master_to_worker" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [format("%s/32", aws_instance.worker.private_ip)]
  security_group_id = aws_security_group.master-sg.id
}


resource "aws_instance" "master" {
    ami                    = var.ami
    instance_type          = var.instance_type
    key_name               = var.key_name
    subnet_id              = var.subnet  
    availability_zone      = var.azone
    iam_instance_profile   = aws_iam_instance_profile.ec2connectprofile.name
    vpc_security_group_ids = [aws_security_group.master-sg.id, aws_security_group.mutual-sg.id]

    user_data              = file("master.sh")

    tags = {
        Name              = "master"
        Role              = "master"
        environment       = "dev"
    }
}

resource "aws_instance" "worker" {
    ami                    = var.ami
    instance_type          = var.instance_type
    key_name               = var.key_name
    subnet_id              = var.subnet
    availability_zone      = var.azone
    iam_instance_profile   = aws_iam_instance_profile.ec2connectprofile.name
    vpc_security_group_ids = [aws_security_group.worker-sg.id, aws_security_group.mutual-sg.id]
    user_data              = templatefile("worker.sh", { region = data.aws_region.current.name, master-id = aws_instance.master.id, master-private = aws_instance.master.private_ip} )
    tags = {
        Name               = "worker"
        Role               = "worker"
        environment        = "dev"
    }
    depends_on = [aws_instance.master]
}
