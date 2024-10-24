provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MainVPC"
  }
}

# Subnet
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "MainSubnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "MainIGW"
  }
}

# Route Table
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "MainRouteTable"
  }
}

# Route Table Association
resource "aws_route_table_association" "main_route_assoc" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

# Security Group
resource "aws_security_group" "allow_traffic" {
  vpc_id = aws_vpc.main_vpc.id

  # Allow incoming traffic for Jenkins, Prometheus, Grafana, and SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Jenkins
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Prometheus
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Grafana
  }

  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AllowJenkinsPrometheusGrafana"
  }
}

# Jenkins Instance
resource "aws_instance" "jenkins" {
  ami           = "ami-04f215f0e52ec06cf"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]

  key_name = aws_key_pair.my_key_pair.key_name # Clave SSH

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install openjdk-11-jdk -y
              sudo apt install -y openssh-server

              # Habilitar autenticación por contraseña
              sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              sudo systemctl restart sshd

              # Crear un usuario con contraseña (usuario: admin, contraseña: password)
              sudo useradd -m admin
              echo 'admin:password' | sudo chpasswd
              sudo usermod -aG sudo admin

              # Instalar Jenkins
              wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
              sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
              sudo apt update -y
              sudo apt install jenkins -y
              sudo systemctl start jenkins
              sudo ufw allow 8080
              EOF

  tags = {
    Name = "JenkinsServer"
  }
}

# Prometheus Instance
resource "aws_instance" "prometheus" {
  ami           = "ami-04f215f0e52ec06cf"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]

  key_name = aws_key_pair.my_key_pair.key_name # Clave SSH

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y openssh-server

              # Habilitar autenticación por contraseña
              sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              sudo systemctl restart sshd

              # Crear un usuario con contraseña
              sudo useradd -m admin
              echo 'admin:password' | sudo chpasswd
              sudo usermod -aG sudo admin

              # Instalar Prometheus
              sudo useradd --no-create-home --shell /bin/false prometheus
              sudo mkdir /etc/prometheus
              sudo mkdir /var/lib/prometheus
              cd /tmp
              wget https://github.com/prometheus/prometheus/releases/download/v2.33.5/prometheus-2.33.5.linux-amd64.tar.gz
              tar -xvf prometheus-2.33.5.linux-amd64.tar.gz
              sudo cp prometheus-2.33.5.linux-amd64/prometheus /usr/local/bin/
              sudo cp prometheus-2.33.5.linux-amd64/promtool /usr/local/bin/
              sudo cp -r prometheus-2.33.5.linux-amd64/consoles /etc/prometheus
              sudo cp -r prometheus-2.33.5.linux-amd64/console_libraries /etc/prometheus
              sudo cp prometheus-2.33.5.linux-amd64/prometheus.yml /etc/prometheus
              sudo tee /etc/systemd/system/prometheus.service <<-EOL
              [Unit]
              Description=Prometheus
              Wants=network-online.target
              After=network-online.target

              [Service]
              User=prometheus
              ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/

              [Install]
              WantedBy=multi-user.target
              EOL
              sudo systemctl daemon-reload
              sudo systemctl start prometheus
              sudo ufw allow 9090
              EOF

  tags = {
    Name = "PrometheusServer"
  }
}

# Grafana Instance
resource "aws_instance" "grafana" {
  ami           = "ami-04f215f0e52ec06cf"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]

  key_name = aws_key_pair.my_key_pair.key_name # Clave SSH

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y openssh-server

              # Habilitar autenticación por contraseña
              sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
              sudo systemctl restart sshd

              # Crear un usuario con contraseña
              sudo useradd -m admin
              echo 'admin:password' | sudo chpasswd
              sudo usermod -aG sudo admin

              # Instalar Grafana
              sudo apt install -y adduser libfontconfig1
              wget https://dl.grafana.com/oss/release/grafana_8.2.2_amd64.deb
              sudo dpkg -i grafana_8.2.2_amd64.deb
              sudo systemctl start grafana-server
              sudo systemctl enable grafana-server
              sudo ufw allow 3000
              EOF

  tags = {
    Name = "GrafanaServer"
  }
}

# Crear un par de claves SSH
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my_key"
  public_key = file("~/.ssh/id_rsa.pub") # Ruta de tu clave pública
}

# Outputs para las IPs públicas
output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "prometheus_public_ip" {
  value = aws_instance.prometheus.public_ip
}

output "grafana_public_ip" {
  value = aws_instance.grafana.public_ip
}
