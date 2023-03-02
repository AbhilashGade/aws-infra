
resource "aws_key_pair" "example" {
  key_name   = "example-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}
resource "aws_instance" "ec2-webapp-dev" {
  count                       = 1
  ami                         = "ami-0ac95c37147119448"
  key_name                    = aws_key_pair.example.key_name
  instance_type               = var.instance_type
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.application.id]
  ebs_optimized               = false
  iam_instance_profile = aws_iam_instance_profile.s3_access_instance_profile.name

  root_block_device {
    volume_size           = 50
    volume_type           = "gp2"
    delete_on_termination = true
  }
  disable_api_termination = false
  tags = {
    Name = var.ec2_tag_name
  }

  #Sending User Data to EC2
  user_data = <<EOT
#!/bin/bash
cat <<EOF > /etc/systemd/system/webapp.service
[Unit]
Description=Webapp Service
After=network.target

[Service]
Environment="NODE_ENV=dev"
Environment="DB_PORT=3306"
Environment="DB_DIALECT=mysql"
Environment="DB_HOST=${element(split(":", aws_db_instance.rds_instance.endpoint), 0)}"
Environment="DB_USER=${aws_db_instance.rds_instance.username}"
Environment="DB_PASSWORD=${aws_db_instance.rds_instance.password}"
Environment="DB=${aws_db_instance.rds_instance.db_name}"
Environment="AWS_BUCKET_NAME=${aws_s3_bucket.webapp-s3.bucket}"
Environment="AWS_REGION=${var.aws_region}"

Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/webapp
ExecStart=/usr/bin/node listener.js
Restart=on-failure

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/webapp.service
EOF


sudo systemctl daemon-reload
sudo systemctl start webapp.service
sudo systemctl enable webapp.service

echo 'export NODE_ENV=dev' >> /home/ec2-user/.bashrc,
echo 'export PORT=3000' >> /home/ec2-user/.bashrc,
echo 'export DB_DIALECT=mysql' >> /home/ec2-user/.bashrc,
echo 'export DB_HOST=${element(split(":", aws_db_instance.rds_instance.endpoint), 0)}' >> /home/ec2-user/.bashrc,
echo 'export DB_USERNAME=${aws_db_instance.rds_instance.username}' >> /home/ec2-user/.bashrc,
echo 'export DB_PASSWORD=${aws_db_instance.rds_instance.password}' >> /home/ec2-user/.bashrc,
echo 'export DB_NAME=${aws_db_instance.rds_instance.db_name}' >> /home/ec2-user/.bashrc,
echo 'export AWS_BUCKET_NAME=${aws_s3_bucket.webapp-s3.bucket}' >> /home/ec2-user/.bashrc,
echo 'export AWS_REGION=${var.aws_region}' >> /home/ec2-user/.bashrc,
source /home/ec2-user/.bashrc
EOT

}