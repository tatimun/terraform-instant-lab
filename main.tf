# Jenkins Instance
resource "aws_instance" "jenkins" {
  ami           = "ami-04f215f0e52ec06cf" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]  # Cambiado a vpc_security_group_ids y usando .id

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install openjdk-11-jdk -y
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
  ami           = "ami-04f215f0e52ec06cf" # Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]  # Cambiado a vpc_security_group_ids y usando .id

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
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
  ami           = "ami-04f215f0e52ec06cf" # Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  key_name      = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_traffic.id]  # Cambiado a vpc_security_group_ids y usando .id

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
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
