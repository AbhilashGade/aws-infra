provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpc_${var.aws_profile}"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(data.aws_availability_zones.available.names) > 2 ? 3 : 2
  cidr_block        = "${var.subnet_prefix}.${count.index + 1}.${var.subnet_suffix}"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Type = var.public_tag
    Name = "${var.public_subnet_name}_${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(data.aws_availability_zones.available.names) > 2 ? 3 : 2
  cidr_block        = "${var.subnet_prefix}.${count.index + 4}.${var.subnet_suffix}"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Type = var.private_tag
    Name = "${var.private_subnet_name}_${count.index + 1}"
  }
}


resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "internet_gateway_${var.aws_profile}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.public_route_table_cidr
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "${var.public_tag}_routetable_${var.aws_profile}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.private_tag}_routetable_${var.aws_profile}"
  }
}

resource "aws_route_table_association" "public_subnets_association" {
  count          = length(aws_subnet.public_subnets.*.id)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnets_association" {
  count          = length(aws_subnet.private_subnets.*.id)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}