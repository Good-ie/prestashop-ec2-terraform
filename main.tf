#Create a VPC (Virtual Private Cloud)
resource "aws_vpc" "prestashop_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "prestashop-vpc"
  }
}
#Create an Internet Gateway (IGW)
resource "aws_internet_gateway" "prestashop_igw" {
  vpc_id = aws_vpc.prestashop_vpc.id

  tags = {
    Name = "prestashop-igw"
  }
}
#Create a Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prestashop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prestashop_igw.id
  }

  tags = {
    Name = "prestashop-public-rt"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.prestashop_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}
#Create a Public Subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
#Create a Security Group
resource "aws_security_group" "prestashop_sg" {
  name        = "prestashop-sg"
  description = "Allow SSH, HTTP, and HTTPS"
  vpc_id      = aws_vpc.prestashop_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prestashop-sg"
  }
}
#Launch EC2 in Custom VPC
resource "aws_instance" "prestashop_ec2" {
  ami                         = "ami-0fc5d935ebf8bc3bc"  # Ubuntu 22.04 LTS in us-east-1
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  key_name                    = "PrestaShop-Intern"  
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.prestashop_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update && apt upgrade -y
              apt install -y software-properties-common
              add-apt-repository ppa:ondrej/php -y
              apt update
              apt install -y libicu-dev
              apt install apache2 mysql-server php7.4 php7.4-mysql php7.4-cli php7.4-curl php7.4-xml php7.4-mbstring php7.4-zip php7.4-gd php7.4-intl unzip wget curl -y

              mysql -e "CREATE DATABASE prestashop;"
              mysql -e "CREATE USER 'psuser'@'localhost' IDENTIFIED BY 'StrongPassword123!';"
              mysql -e "GRANT ALL PRIVILEGES ON prestashop.* TO 'psuser'@'localhost';"
              mysql -e "FLUSH PRIVILEGES;"

              cd /var/www/html
              rm index.html
              wget https://github.com/PrestaShop/PrestaShop/releases/download/1.7.8.10/prestashop_1.7.8.10.zip
              unzip prestashop_1.7.8.10.zip
              mv prestashop/* ./
              rm -rf prestashop prestashop_1.7.8.10.zip
              chown -R www-data:www-data /var/www/html
              chmod -R 755 /var/www/html

              cat << APACHE > /etc/apache2/sites-available/prestashop.conf
              <VirtualHost *:80>
                  DocumentRoot /var/www/html
                  <Directory /var/www/html/>
                      AllowOverride All
                  </Directory>
              </VirtualHost>
              APACHE

              a2ensite prestashop.conf
              a2enmod rewrite
              systemctl restart apache2
              EOF

  tags = {
    Name = "PrestaShop-EC2"
  }
}