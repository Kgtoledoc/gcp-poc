# Configure the Google Cloud Provider
terraform {
  required_version = ">= 0.14"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}

# Data source to get the latest Ubuntu image
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

# Create VPC
resource "google_compute_network" "web_app_vpc" {
  name                    = "web-app-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
}

# Create subnet
resource "google_compute_subnetwork" "web_app_subnet" {
  name          = "web-app-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.web_app_vpc.id
}

# Create firewall rule for HTTP traffic
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.web_app_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# Create firewall rule for SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.web_app_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# Create Compute Engine instance
resource "google_compute_instance" "web_server_1" {
  name         = "web-server-1"
  machine_type = "e2-medium"
  zone         = var.zone

  tags = ["web-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.web_app_vpc.id
    subnetwork = google_compute_subnetwork.web_app_subnet.id

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Create index.html
    cat > /var/www/html/index.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>GCP Technical Test</title>
    <meta charset="utf-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 100px;
            background-color: #f0f0f0;
        }
        .container {
            background-color: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            max-width: 600px;
            margin: 0 auto;
        }
        h1 {
            color: #4285f4;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>¡Bienvenido a la prueba técnica de GCP!</h1>
        <p>Esta aplicación web ha sido desplegada usando Terraform y Google Cloud Platform.</p>
        <p><strong>Infraestructura desplegada:</strong></p>
        <ul style="text-align: left; display: inline-block;">
            <li>VPC: web-app-vpc</li>
            <li>Subnet: web-app-subnet</li>
            <li>Instancia: web-server-1 (e2-medium)</li>
            <li>Servidor web: Nginx</li>
        </ul>
    </div>
</body>
</html>
EOL
    
    systemctl restart nginx
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }
}

# Output the external IP
output "instance_external_ip" {
  value = google_compute_instance.web_server_1.network_interface[0].access_config[0].nat_ip
}

output "instance_name" {
  value = google_compute_instance.web_server_1.name
}

output "vpc_name" {
  value = google_compute_network.web_app_vpc.name
}

output "subnet_name" {
  value = google_compute_subnetwork.web_app_subnet.name
}

output "ubuntu_image_used" {
  value = data.google_compute_image.ubuntu.self_link
}
