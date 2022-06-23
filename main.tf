provider "google" {
  project = "carbide-ego-343511"  # GCP Projekt in welchem die Infrastruktur aufgebaut werden soll
}

# Variablen können dazu definiert werden, um diese mehrfach im Terraform Code zu nutzen
variable "ssh" {
  type = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDsBIZkkJQdfo8HG32SbUBQLvhta4IFdAulrf72FcYZdQLCcAdAhELcTVvLVVzhyGYsy+qmD2rPBSg8Kq5RwyszaymkjZVtbGYw/nF4sB6piKbed5Ntdt2UMxu5o/m1fnvsVrBjeron8i/5VjQ0gUiAj673hSWNDjFyzyWWPy12AebOxJx0b5rzBXvHvh+mov5aMmlgMex3pIuHlrJ5S6vj26NUd2XnvaqFgzCETxb/VY2BzkfMNjwa/xU2zp+ThLtFeO5oqqePxXwu5/hOapg7k7XiCYN260d4f9NyoOzjL9M4aVuU5qSKuULJRhlcBNiqBJpT2Ts4561oYApc+nKP garzielia20"
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

# Mit google_project_service steuert man, welche GCP APIs aktiv sind. Für die Erstellung von VMs, Netzwerken und GKE Clustern
# braucht es z.B. die Compute Instance API, oder die Container API.
# Eine Liste aller GCP API Namen kann man über die GCP SDK Shell abrufen: gcloud services list --available
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "container-service" {
  service = "container.googleapis.com"
}

resource "google_project_service" "iam-service" {
  service = "iam.googleapis.com"
}

resource "google_project_service" "artifactregistry-service" {
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "compute-service" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "storage-service" {
  service = "storage-api.googleapis.com"
}


# Die Artifacs Registry für das Hochladen von Docker Images, um diese später auf dem Kubernetescluster zu betreiben
#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
resource "google_artifact_registry_repository" "my-repo" {
  depends_on = [
    google_project_service.artifactregistry-service
  ]

  provider = google-beta
  location = "europe-west6" # Die Containerregistry läuft in der Region Zürich
  repository_id = "dockerimages" 
  description = "Zuericloud Docker repository"
  format = "DOCKER" # Die Containerregistry ist für Docker Images ausgelegt
}

# Storage Bucket für Scripts, die beim installieren der Compute Engine Instanzen genutzt werden sollen
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "instance-script-storage-bucket" {
  depends_on = [
    google_project_service.storage-service # Der Storage Bucket ist abhängig davon, dass die Storage-service API aktiviert ist
  ]

  name          = "instance-init-scripts"
  location      = "europe-west6" # Der Storage Bucket wird in der Region Zürich gespeichert
  force_destroy = true
}

resource "google_service_account" "instance-storage" {
  depends_on = [
    google_project_service.iam-service # Der Service Account ist abhängig davon, dass die IAM API aktiviert ist
  ]

  account_id   = "instance-bucket-user"
  display_name = "instance-bucket-user"
}

# Netzwerke, die später für die Firewallregeln gebraucht werden
#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "production" {
  description = "Network for production workloads for Zuericloud AG"
  name = "production"
  auto_create_subnetworks = false # Mit "true" würde für jede Zone ein Subnetz erstellt werden
}

resource "google_compute_network" "management" {
  description = "Network for managing Zuericloud AG infrastructure"
  name = "management"
  auto_create_subnetworks = false # Mit "true" würde für jede Zone ein Subnetz erstellt werden
}


resource "google_compute_subnetwork" "production-zh1" {
  depends_on = [
    google_compute_network.production # Das Subnetz ist abhängig davon, dass das Netzwerk production bereits erstellt ist
  ]

  name          = "production-zh1"
  ip_cidr_range = "10.172.0.0/24"
  region        = "europe-west6"
  network       = google_compute_network.production.name
}

resource "google_compute_subnetwork" "management-zh1" {
  depends_on = [
    google_compute_network.management  # Das Subnetz ist abhängig davon, dass das Netzwerk management bereits erstellt ist
  ]

  name          = "management-zh1"
  ip_cidr_range = "10.60.0.0/24"
  region        = "europe-west6"
  network       = google_compute_network.management.name
}


# Alle Firewallregeln. Liste zu den Firewallregeln findet man im Readme.md
resource "google_compute_firewall" "allow-iap-in-mgm" {
  depends_on = [
    google_compute_subnetwork.management-zh1
  ]

  name    = "allow-iap-in-mgm" # Name der Firewall Rule
  network = google_compute_network.management.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["ssh-server"] #Array, weil es mehrere sein können
}

resource "google_compute_firewall" "allow-ssh-in-mgm" {
  depends_on = [
    google_compute_subnetwork.management-zh1
  ]

  name    = "allow-ssh-in-mgm" # Name der Firewall Rule
  network = google_compute_network.management.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_tags = ["wireguard-server"]
  target_tags = ["ssh-server"]
}

resource "google_compute_firewall" "allow-vpn-in-mgm" {
  depends_on = [
    google_compute_subnetwork.management-zh1
  ]

  name    = "allow-vpn-in-mgm" # Name der Firewall Rule
  network = google_compute_network.management.name

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  target_tags = [ "wireguard-server" ]
}

resource "google_compute_firewall" "allow-http-in-prod" {
  depends_on = [
    google_compute_subnetwork.production-zh1
  ]

  name    = "allow-http-in-prod" # Name der Firewall Rule
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  target_tags = [ "entrypoint" ]
}

resource "google_compute_firewall" "allow-https-in-prod" {
  depends_on = [
    google_compute_subnetwork.production-zh1
  ]

  name    = "allow-https-in-prod" # Name der Firewall Rule
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  target_tags = [ "entrypoint" ]
}

resource "google_compute_firewall" "allow-smtp-in-prod" {
  depends_on = [
    google_compute_subnetwork.production-zh1
  ]

  name    = "allow-smtp-in-prod" # Name der Firewall Rule
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports    = ["24", "465", "587"]
  }

  source_ranges = [ "0.0.0.0/0" ]
  target_tags = [ "smtp-server" ]
}

resource "google_compute_firewall" "allow-proxied-http-in-prod" {
  depends_on = [
    google_compute_subnetwork.production-zh1
  ]

  name    = "allow-proxied-http-in-prod" # Name der Firewall Rule
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_tags = [ "entrypoint" ]
  target_tags = [ "server-http" ]
}

resource "google_compute_firewall" "allow-proxied-https-in-prod" {
  depends_on = [
    google_compute_subnetwork.production-zh1
  ]

  name    = "allow-proxied-https-in-prod" # Name der Firewall Rule
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_tags = [ "entrypoint" ]
  target_tags = [ "server-https" ]
}

# Kubernetes Cluster
#https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  depends_on = [
    google_compute_network.management,
    google_project_service.container-service
  ]

  name               = "gke-zh1"
  location           = "europe-west6"
  network = google_compute_network.management.name
  subnetwork = google_compute_subnetwork.management-zh1.name
  enable_autopilot = true
  ip_allocation_policy {
  }
  # cluster_ipv4_cidr = "10.44.0.0/16"
  # initial_node_count = 2
 

  # database_encryption {
  #   state = "ENCRYPTED"
  #   key_name = "geheimerkey123" #######################################################################Dies in ENV Speichern
  # }
}

# VM für den Reverse Proxy
resource "google_compute_instance" "reverse-proxy" {
  depends_on = [
    google_project_service.compute-service, # Compute Engine API muss aktiv sein 
    google_compute_network.management, # Management Netzwerk muss erstellt sein
    google_compute_network.production, # Production Netzwerk muss erstellt sein
    google_service_account.instance-storage # Service Account "instance-storage" muss existieren
  ]

  name         = "srv-proxy-zh1"
  machine_type = "e2-medium" # Instanztyp -> 1 vCpu und 4 GiB Ram
  zone         = "europe-west6-a"
  tags         = ["entrypoint", "ssh-server", "wireguard-server", "server-http"]
  deletion_protection = true

  shielded_instance_config {
      enable_vtpm = "true"
  }
  
  boot_disk {
    initialize_params {
      size = "20" #Speicher in GB
      type = "pd-balanced" #Disk Typ: Ausgeglichen nichtflüchtiger Speicher
      image = "rhel-cloud/rhel-8"
    }
  }
    
  network_interface {
    subnetwork = google_compute_subnetwork.management-zh1.name
    network_ip = "10.172.0.5"
    stack_type = "IPV4_ONLY"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.production-zh1.name
    network_ip = "10.60.0.5"
    stack_type = "IPV4_ONLY"
    access_config {
      #nat_ip = "34.65.164.210"
      nat_ip = ""
      #public_ptr_domain_name = "zuericloud.ch"
    }
  }

  scheduling {
     on_host_maintenance = "migrate"
  }

  service_account {
    email  = google_service_account.instance-storage.email
    scopes = ["cloud-platform"]
  }

    metadata = {
    "ssh-keys" = var.ssh
    "startup-script-url" = "https://storage.cloud.google.com/terraform-init-scripts/test.sh"
  }
}

# VM für Nextcloud Server 
resource "google_compute_instance" "container-host-2" {
  depends_on = [
    google_project_service.compute-service,
    google_compute_subnetwork.management-zh1,
    google_compute_subnetwork.production-zh1,
    google_service_account.instance-storage
  ]

  name         = "srv-container2-zh1"
  machine_type = "e2-medium" # Instanztyp -> 1 vCpu und 4 GiB Ram
  zone         = var.zones["europe-1"] # Zone, in welcher die VM läuft
  tags         = ["ssh-server", "server-http"] # Tags um den Netzwerktraffic auf der Firewall zuzuordnen
  deletion_protection = true # Die VM kann nicht "einfach so" gelöscht werden

  shielded_instance_config {
      enable_secure_boot = "true" # Secure Boot für die VM
      enable_vtpm = "true" # Virtual Trusted Platform Module für das Speichern von Security Keys
  }
  
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-8" # Image Red Hat Enterprise Linux 8
      size = "25" #Speicher in GB
      type = "pd-balanced" #Disk Typ: Ausgeglichen nichtflüchtiger Speicher
    }
  }
    
  network_interface {
    subnetwork = google_compute_subnetwork.management-zh1.name
    network_ip = "10.172.0.4"
    stack_type = "IPV4_ONLY"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.production-zh1.name
    network_ip = "10.60.0.8"
    stack_type = "IPV4_ONLY" # VM nutzt nur IPv4 und kein IPv6
    access_config {
      # Wenn nat_ip leer ist, wird die Public IP dynamisch vergeben
      nat_ip = "" 
    }
  }

  scheduling {
     on_host_maintenance = "migrate" # Im Falle einer Hostwartung, wird die VM live-migriert
  }

  service_account {
    email  = google_service_account.instance-storage.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    "ssh-keys" = var.ssh
    "startup-script-url" = "https://storage.cloud.google.com/terraform-init-scripts/test.sh"
  }
}

# VM für den Mail Server 
resource "google_compute_instance" "mail-host-1" {
  depends_on = [
    google_project_service.compute-service,
    google_compute_subnetwork.management-zh1,
    google_compute_subnetwork.production-zh1,
    google_service_account.instance-storage
  ]

  name         = "srv-mail1-zh1"
  machine_type = "e2-medium" # Instanztyp -> 1 vCpu und 4 GiB Ram
  zone         = var.zones["europe-1"]
  tags         = ["ssh-server", "server-http", "smtp-server"]
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
    subnetwork = google_compute_subnetwork.management-zh1.name
    network_ip = "10.172.0.3"
    stack_type = "IPV4_ONLY"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.production-zh1.name
    network_ip = "10.60.0.10"
    stack_type = "IPV4_ONLY"
    access_config {
      nat_ip = ""
      #nat_ip = "34.65.169.233"
      #public_ptr_domain_name = "mx1.zuericloud.ch"
    }
  }

  scheduling {
     on_host_maintenance = "migrate"
  }

  service_account {
    email  = google_service_account.instance-storage.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    "ssh-keys" = var.ssh
    "startup-script-url" = "https://storage.cloud.google.com/terraform-init-scripts/test.sh"
  }
}