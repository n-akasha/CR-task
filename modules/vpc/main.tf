# Availability Zones
data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "nedaltask_VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "nedaltaskGW"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnets)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.public_subnets, count.index)
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "nedaltask_Public_Subnet"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnets)
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = element(var.private_subnets, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "nedaltask_Private_Subnet"
  }
}

# NAT Gateway and EIP for Public Subnets
resource "aws_eip" "nat_eip1" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway1" {
  allocation_id = aws_eip.nat_eip1.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "nedaltask_nat_gw1"
  }
}

resource "aws_eip" "nat_eip2" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway2" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.public[1].id
  tags = {
    Name = "nedaltask_nat_gw2"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table and NAT Gateways Association
resource "aws_route_table" "private_rt" {
  count = length(var.private_subnets)  # Count based on the number of private subnets
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element([aws_nat_gateway.nat_gateway1.id, aws_nat_gateway.nat_gateway2.id], count.index % 2)  # Alternate NAT gateways per subnet
  }

  tags = {
    Name = "nedaltask_Private_RT_${count.index}"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_rt_assoc" {
  count          = length(var.private_subnets)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private_rt[count.index].id
}
