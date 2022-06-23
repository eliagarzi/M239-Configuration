provider "google" {
  project = "symmetric-hull-345606"
}

# Variablen
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

# Artifacs Registry für das Hochladen von Docker Images, um diese später auf dem Kubernetescluster zu betreiben
#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
# resource "google_artifact_registry_repository" "my-repo" {
#   provider = google-beta
#   location = "europe-west6"
#   repository_id = "dockerimages"
#   description = "Zuericloud Docker repository"
#   format = "DOCKER"
# }

# Netzwerke, die später für die Firewallregeln gebraucht werden
#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "production" {
  description = "Network for production workloads for Zuericloud AG"
  name = "production"
  auto_create_subnetworks = false
}

resource "google_compute_network" "management" {
  description = "Network for managing Zuericloud AG infrastructure"
  name = "management"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "production-zh1" {
  name          = "production-zh1"
  ip_cidr_range = "10.172.0.0/24"
  region        = "europe-west6"
  network       = "production"

}

resource "google_compute_subnetwork" "management-zh1" {
  name          = "management-zh1"
  ip_cidr_range = "10.60.0.0/24"
  region        = "europe-west6"
  network       = "management"
}


# Alle Firewallregeln. Liste zu den Firewallregeln findet man im Readme.md
resource "google_compute_firewall" "allow-iap-in-mgm" {
  name    = "allow-iap-in-mgm" # Name der Firewall Rule
  network = "management"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["ssh-server"] #Array, weil es mehrere sein können
}

resource "google_compute_firewall" "allow-ssh-in-mgm" {
  name    = "allow-ssh-in-mgm" # Name der Firewall Rule
  network = "management"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = ["wireguard-server"]
  target_tags = ["ssh-server"]
}

resource "google_compute_firewall" "allow-vpn-in-mgm" {
  name    = "allow-vpn-in-mgm" # Name der Firewall Rule
  network = "management"

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  destination_tags = [ "wireguard-server" ]
}

resource "google_compute_firewall" "allow-http-in-prod" {
  name    = "allow-http-in-prod" # Name der Firewall Rule
  network = "external-production"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  destination_tags = [ "entrypoint" ]
}

resource "google_compute_firewall" "allow-https-in-prod" {
  name    = "allow-https-in-prod" # Name der Firewall Rule
  network = "external-production"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  destination_tags = [ "entrypoint" ]
}

resource "google_compute_firewall" "allow-https-in-prod" {
  name    = "allow-https-in-prod" # Name der Firewall Rule
  network = "external-production"

  allow {
    protocol = "tcp"
    ports    = ["24", "465", "587"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  destination_tags = [ "smtp-server" ]
}

resource "google_compute_firewall" "allow-proxied-http-in-prod" {
  name    = "allow-proxied-http-in-prod" # Name der Firewall Rule
  network = "internal-production"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [ "entrypoint" ]
  destination_tags = [ "internal-server-http" ]
}

resource "google_compute_firewall" "allow-proxied-https-in-prod" {
  name    = "allow-proxied-https-in-prod" # Name der Firewall Rule
  network = "internal-production"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [ "entrypoint" ]
  destination_tags = [ "internal-server-https" ]
}

# Kubernetes Cluster
#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name               = "gke-zh1"
  location           = var.zones["europe-1"]
  cluster_ipv4_cidr = "10.0.44.0/16"
  initial_node_count = 2
  enable_autopilot = true

  database_encryption {
    state = "ENCRYPTED"
    key_name = "geheimerkey123" #######################################################################Dies in ENV Speichern
  }

  vertical_pod_autoscaling {
    enabled = false
  }

  default_snat_status {
    disabled = true
  }

  cluster_autoscaling {
    enabled = false
  }
}

# VM für den Reverse Proxy
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

# VM für Nextcloud Server 
resource "google_compute_instance" "container-host-2" {
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
    network = "default"
    network_ip = "10.172.0.50"
    stack_type = "IPV4_ONLY"
  }

  # network_interface {
  #   network = "production"
  #   network_ip = "10.60.0.8"
  #   stack_type = "IPV4_ONLY"
  #   access_config {
  #     nat_ip = ""
  #   }
  # }

  scheduling {
     on_host_maintenance = "migrate"
  }

  metadata = {
    "startup-script-url" = "https://storage.cloud.google.com/terraform-init-scripts/test.sh"
  }
}

# VM für den Mail Server 
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