provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  tags = {
    Name = "${var.vpc_name}-${var.cidr_block}"
  }
}

resource "aws_subnet" "public" {
  count             = 3
  cidr_block        = "${var.sub_prefix}${count.index + 1}${var.sub_postfix}"
  vpc_id            = aws_vpc.main.id
  availability_zone = "${var.aws_region}${var.availability_zones[count.index]}"

  tags = {
    Name = "${var.public_subnet_name}-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 3
  cidr_block        = "${var.sub_prefix}${count.index + 4}${var.sub_postfix}"
  vpc_id            = aws_vpc.main.id
  availability_zone = "${var.aws_region}${var.availability_zones[count.index]}"

  tags = {
    Name = "${var.private_subnet_name}-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.gateway_name}-${var.cidr_block}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.cidr_gateway
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.public_table_name}-${var.cidr_block}"
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.private_table_name}-${var.cidr_block}"
  }

}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create security group for EC2 instance
resource "aws_security_group" "application" {
  name_prefix = var.security_group_name
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = var.ports[0]
    to_port     = var.ports[0]
    protocol    = var.protocol
    cidr_blocks = [var.cidr_gateway]
  }

  ingress {
    from_port   = var.ports[1]
    to_port     = var.ports[1]
    protocol    = var.protocol
    cidr_blocks = [var.cidr_gateway]
  }

  ingress {
    from_port   = var.ports[2]
    to_port     = var.ports[2]
    protocol    = var.protocol
    cidr_blocks = [var.cidr_gateway]
  }

  ingress {
    from_port   = var.ports[3]
    to_port     = var.ports[3]
    protocol    = var.protocol
    cidr_blocks = [var.cidr_gateway]
  }

  egress {
    from_port   = var.ports[4]
    to_port     = var.ports[4]
    protocol    = var.eprotocol
    cidr_blocks = [var.cidr_gateway]
  }
}

resource "aws_key_pair" "app_keypair" {
  key_name   = var.keypair_name
  public_key = file(var.keypair_path)
}

resource "aws_ebs_volume" "ebs_volume" {
  availability_zone = "${var.aws_region}${var.availability_zones[0]}"
  size              = var.ebs_volume_size
  type              = var.ebs_volume_type
  tags = {
    Name = var.ebs_volume_name
  }
}



# create IAM instance profile
resource "aws_iam_instance_profile" "profile" {
  name = "ec2-profile"
  role = aws_iam_role.EC2-CSYE6225.name
}

# Launch EC2 instance
resource "aws_instance" "csye_ec2" {
  ami                    = "ami-0a50e67d1c3cb04b5"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.application.id]
  tags = {
    Name = var.ec2_name
  }
  key_name = aws_key_pair.app_keypair.key_name

  associate_public_ip_address = true
  disable_api_termination     = false

  root_block_device {
    volume_size           = 50
    delete_on_termination = true
  }

  # Attach IAM role to instance
  iam_instance_profile = aws_iam_instance_profile.profile.name

  # Add SSH key to the instance
  connection {
    type        = var.connection_type
    user        = var.user
    private_key = file(var.privatekey_path)
    timeout     = var.ssh_timeout
    host        = self.public_ip
  }


  user_data = <<EOT
#!/bin/bash
cat <<EOF > /etc/systemd/system/webapp.service
[Unit]
Description=Webapp Service
After=network.target

[Service]
Environment="NODE_ENV=dev"
Environment="DB_PORT=3000"
Environment="DIALECT=mysql"
Environment="DB_HOST=${aws_db_instance.default.address}"
Environment="DB_USERNAME=${aws_db_instance.default.username}"
Environment="DB_PASSWORD=${aws_db_instance.default.password}"
Environment="DB_NAME=${aws_db_instance.default.db_name}"
Environment="AWS_BUCKET_NAME=${aws_s3_bucket.private_bucket.bucket}"
Environment="AWS_REGION=${var.aws_region}"

Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/webapp
ExecStart=/usr/bin/node server-listener.js
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/webapp.service
EOF

sudo systemctl daemon-reload
sudo systemctl start webapp.service
sudo systemctl enable webapp.service

echo 'export NODE_ENV=dev' >> /home/ec2-user/.bashrc,
echo 'export DB_PORT=3000' >> /home/ec2-user/.bashrc,
echo 'export DIALECT=mysql' >> /home/ec2-user/.bashrc,
echo 'export DB_HOST=${aws_db_instance.default.address}' >> /home/ec2-user/.bashrc,
echo 'export DB_USERNAME=${aws_db_instance.default.username}' >> /home/ec2-user/.bashrc,
echo 'export DB_PASSWORD=${aws_db_instance.default.password}' >> /home/ec2-user/.bashrc,
echo 'export DB_NAME=${aws_db_instance.default.db_name}' >> /home/ec2-user/.bashrc,
echo 'export AWS_BUCKET_NAME=${aws_s3_bucket.private_bucket.bucket}' >> /home/ec2-user/.bashrc,
echo 'export AWS_REGION=${var.aws_region}' >> /home/ec2-user/.bashrc,
source /home/ec2-user/.bashrc
EOT
}

resource "aws_volume_attachment" "ebsAttach" {

  device_name = var.device_name
  volume_id   = aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.csye_ec2.id

}

# Allocate Elastic IP
resource "aws_eip" "ec2_eip" {
  vpc = true
}

# Associate Elastic IP with EC2 instance
resource "aws_eip_association" "ec2_eip_assoc" {
  instance_id   = aws_instance.csye_ec2.id
  allocation_id = aws_eip.ec2_eip.id
}

resource "random_string" "random" {
  length           = 8
  special          = false
  upper            = false
}

# Create S3 bucket with a random name
resource "aws_s3_bucket" "private_bucket" {
  bucket        = "${var.AWS_BUCKET_NAME}${random_string.random.result}${var.aws_profile}"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.private_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_bucket" {
  bucket = aws_s3_bucket.private_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure S3 bucket lifecycle policy to delete objects
resource "aws_s3_bucket_lifecycle_configuration" "private_bucket_lifecycle" {
  bucket = aws_s3_bucket.private_bucket.id
  rule {
    id     = "delete-objects"
    status = "Enabled"
    prefix = ""
    expiration {
      days = 30
    }
  }

  rule {
    id     = "transition-to-standard-ia"
    status = "Enabled"
    prefix = ""
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Configure S3 bucket versioning
resource "aws_s3_bucket_versioning" "private_bucket_versioning" {
  bucket = aws_s3_bucket.private_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Create IAM policy for S3 access
resource "aws_iam_policy" "WebAppS3" {
  name        = "WebAppS3"
  description = "Allows EC2 instances to access S3 buckets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket"

        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.private_bucket.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.private_bucket.bucket}"
        ]
      }
    ]
  })
}

# Create IAM role for EC2 instance
resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach S3 access policy to IAM role
resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  policy_arn = aws_iam_policy.WebAppS3.arn
  role       = aws_iam_role.EC2-CSYE6225.name
}

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = var.DB_USER
  engine               = "mysql"
  instance_class       = "db.t3.micro"
  identifier           = var.DB_USER
  username             = var.DB_USER
  password             = var.DB_PASSWORD
  multi_az             = false
  publicly_accessible  = false
  parameter_group_name = aws_db_parameter_group.my_parameter_group.id
  skip_final_snapshot  = true
  apply_immediately    = true
  backup_retention_period = 0
  vpc_security_group_ids = [
    aws_security_group.database_security_group.id
  ]

  db_subnet_group_name = aws_db_subnet_group.my_subnet_group.name

  tags = {
    Name = var.DB_USER
  }
}

data "aws_db_instance" "default" {
  db_instance_identifier = aws_db_instance.default.id
}

resource "aws_db_parameter_group" "my_parameter_group" {
  name   = "my-parameter-group"
  family = "mysql8.0"

  parameter {
    name  = "max_allowed_packet"
    value = "67108864"
  }
}

resource "aws_db_subnet_group" "my_subnet_group" {
  name        = "my-subnet-group"
  description = "My subnet group for RDS instance"

  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id, aws_subnet.private[2].id]
}

resource "aws_security_group" "database_security_group" {
  description = "Security group for RDS instances"
  name        = "database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = [
      aws_security_group.application.id
    ]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}