#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
resource "google_artifact_registry_repository" "my-repo" {
  provider = google-beta
  location = "europe-west6"
  repository_id = "dockerimages"
  description = "Zuericloud Docker repository"
  format = "DOCKER"
}

resource "google_compute_firewall" "allow-smtp-in" {
  name    = "allow-smtp-in" # Name der Firewall Rule
  network = "production"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["free"] #Array, weil es mehrere sein können
}

resource "google_compute_firewall" "allow-wireguard-in" {
  name    = "allow-wireguard-in" # Name der Firewall Rule
  network = "management"

  allow {
    protocol = "tcp"
    ports    = ["34480"]
  }

  source_ranges = ["0.0.0.0/0"] 
  destination_ranges = ["10.172.0.0/24"]
}

resource "google_compute_firewall" "allow-iap-in" {
  name    = "allow-iap-in" # Name der Firewall Rule
  network = "management"

  allow {
    protocol = "tcp"
    ports    = ["51820"]
  }

  source_ranges = ["35.235.240.0/20"] 
  destination_ranges = ["10.172.0.0/24"]
}

provider "google" {
  project = "symmetric-hull-345606"
}

#Reverse Proxy
resource "google_compute_instance" "reverse proxy" {
  name         = "srv-proxy-zh1"
  machine_type = "f1-micro"
  zone         = "europe-west6-a"
  tags         = ["entrypoint", "ssh-server", "wireguard-server", "internal-server-http"]
  deletion_protection = true

  shielded_instance_config {
      enable_vtpm = "true"
  }
  
  boot_disk {
    initialize_params {
      size = "15" #Speicher in GB
      type = "pd-balanced" #Disk Typ: Ausgeglichen nichtflüchtiger Speicher
      image = "rhel-cloud/rhel-8"
    }
  }
    
  network_interface {
    network = "management"
    network_ip = "10.172.0.5"
    stack_type = "IPV4_ONLY"
  }

  network_interface {
    network = "production"
    network_ip = "10.60.0.5"
    stack_type = "IPV4_ONLY"
    access_config {
      nat_ip = "34.65.164.210"
      public_ptr_domain_name = "zuericloud.ch"
    }
  }

  scheduling {
     on_host_maintenance = "migrate"
  }
}

variable "ssh_pub_key_file" {
  type = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsBIZkkJQdfo8HG32SbUBQLvhta4IFdAulrf72FcYZdQLCcAdAhELcTVvLVVzhyGYsy+qmD2rPBSg8Kq5RwyszaymkjZVtbGYw/nF4sB6piKbed5Ntdt2UMxu5o/m1fnvsVrBjeron8i/5VjQ0gUiAj673hSWNDjFyzyWWPy12AebOxJx0b5rzBXvHvh+mov5aMmlgMex3pIuHlrJ5S6vj26NUd2XnvaqFgzCETxb/VY2BzkfMNjwa/xU2zp+ThLtFeO5oqqePxXwu5/hOapg7k7XiCYN260d4f9NyoOzjL9M4aVuU5qSKuULJRhlcBNiqBJpT2Ts4561oYApc+nKP garzielia20"
}

variable "ssh_user" {
  type = string
  default = "garzielia20"
}

#Speichert die Standardzone unter anderem Namen
variable "zones" {
  type = map
  default = {
    "europe-1" = "europe-west6-a"
    "europe-2" = "europe-west2-a"
    "usa-1" = "us-central1-a"
    "usa-2" = "northamerica-northeast1-b"
  }
}

# Kubernetes Cluster
resource "google_container_cluster" "primary" {
  name               = "gke-zh1"
  location           = var.zones["europe-1"]
  initial_node_count = 2

  node_config {
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  timeouts {
    create = "30m"
    update = "40m"
  }
}

#  Nextcloud Server 
resource "google_compute_instance" "container host 2" {
  name         = "srv-container2-zh1"
  machine_type = "f1-micro"
  zone         = var.zones["europe-1"]
  tags         = ["ssh-server", "internal-server-http"]
  deletion_protection = true

  shielded_instance_config {
      enable_secure_boot = "true"
      enable_vtpm = "true"
  }
  
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-8"
      size = "25" #Speicher in GB
      type = "pd-balanced" #Disk Typ: Ausgeglichen nichtflüchtiger Speicher
    }
  }
    
  network_interface {
    network = "management"
    network_ip = "10.172.0.8"
    stack_type = "IPV4_ONLY"
  }

  network_interface {
    network = "production"
    network_ip = "10.60.0.8"
    stack_type = "IPV4_ONLY"
    access_config {
      nat_ip = ""
    }
  }

  scheduling {
     on_host_maintenance = "migrate"
  }
}

#  Mail Server 
resource "google_compute_instance" "mail host 1" {
  name         = "srv-mail1-zh1"
  machine_type = "f1-micro"
  zone         = var.zones["europe-1"]
  tags         = ["ssh-server", "internal-server-http", "smtp-server"]
  deletion_protection = true

  shielded_instance_config {
      enable_secure_boot = "true"
      enable_vtpm = "true"
  }
  
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size = "25" #Speicher in GB
      type = "pd-balanced" #Disk Typ: Ausgeglichen nichtflüchtiger Speicher
    }
  }
    
  network_interface {
    network = "management"
    network_ip = "10.172.0.10"
    stack_type = "IPV4_ONLY"
  }

  network_interface {
    network = "production"
    network_ip = "10.60.0.10"
    stack_type = "IPV4_ONLY"
    access_config {
      nat_ip = "34.65.169.233"
      public_ptr_domain_name = "mx1.zuericloud.ch"
    }
  }

  scheduling {
     on_host_maintenance = "migrate"
  }
}