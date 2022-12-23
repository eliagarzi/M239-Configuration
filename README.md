# Terraform und Kubernetes auf Google Cloud Platform - Modul 239

Für das Modul 239 mussten wir verschiedene Internetservices aufbauen. Dazu nutze ich die Google Cloud Platform, um Erfahrungen mit einer Public Cloud zu sammeln. Anschliessend habe ich meine Modularbeit erweitert mit Terraform und Kubernetes.

- [Terraform und Kubernetes auf Google Cloud Platform - Modul 239](#terraform-und-kubernetes-auf-google-cloud-platform---modul-239)
  - [Überblick](#überblick)
    - [Was ist Terraform?](#was-ist-terraform)
    - [Was ist Kubernetes?](#was-ist-kubernetes)
  - [Terraform](#terraform)
    - [Wie funktioniert Terraform?](#wie-funktioniert-terraform)
    - [Terraform Befehle](#terraform-befehle)
    - [Terraform in einem Team](#terraform-in-einem-team)
  - [Terraform Infrastruktur](#terraform-infrastruktur)
    - [Netzwerke](#netzwerke)
    - [Subnetze](#subnetze)
    - [Firewallregeln](#firewallregeln)
    - [Compute Engine Instanzen](#compute-engine-instanzen)
      - [Allgmeine Konfiguration](#allgmeine-konfiguration)
      - [SSH Keys](#ssh-keys)
      - [Startscript](#startscript)
  - [Kubernetes](#kubernetes)
    - [Kubernetes Architektur](#kubernetes-architektur)
      - [Master Node](#master-node)
      - [Worker Node](#worker-node)
      - [Weitere Bestandtiele](#weitere-bestandtiele)
  - [Google Cloud Platform](#google-cloud-platform)
    - [Allgemeines](#allgemeines)
      - [GCP 400$ Kredit](#gcp-400-kredit)
      - [Organisation, Ordner und Projekt](#organisation-ordner-und-projekt)
      - [Region und Zone](#region-und-zone)
      - [Zugriff](#zugriff)
      - [APIs](#apis)

## Überblick

### Was ist Terraform?

Terraform ist ein Infrastructure as Code (IaC) Tool, welches von HashiCorp (Entwickler von Vagrant) entwickelt wird. Mit Terraform ist es möglich, über die APIs vieler Plattformen wie GCP, Azure, AWS oder sogar VMware vSphere Infrastrukturen deklarativ hochzuziehen. Die ganze Arbeit, die ich für das Modul 239 manuell über die Google Cloud Console gemacht habe, kann ich so mit nur einem einzigen Script innert 10 Minuten erstellen lassen.

### Was ist Kubernetes?

Kubernetes ist ein Containerorechstrierungstool, welches von Google entwickelt wurde. Dementsprechend hat Google mit der Google Kubernetes Engine (GKE) auf GCP ihren eigenen "Kubernetes as a Service". Für das Modul 239 habe ich alle Anwendungen mit Docker entwickelt und entsprechende Images erstellt. Diese Container liefen aber auf Google Compute Engine Instanzen, also virtuellen Maschinen, und nicht auf Kubernetes. Um in die Welt von Kubernetes einzusteigen, habe ich also anschliessend GKE genutzt, um meine Container auf Kubernetes zu deployen.

## Terraform

---

Bevor man beginnt, das Terraform File zu entwickeln, ist es wichtig zu definieren, welche Ressourcen gebraucht werden und wie diese konfiguriert werden sollen.

Terraform ist ein Infrastructure as Code (IaC) Tool. Es ermöglicht die Erstellung von Ressourcen deklarativ auf vielen verschiedenen Plattformen. Darunter auch AWS, Azure und GCP. Aber auch On Premise Lösungen wie VMware vSphere stehen zur Verfügung.

### Wie funktioniert Terraform?

**Terraform Provider:**

Ein Terraform Provider ist ein Plugin, welches die Kommunikation zwischen Terraform und der Plattform (Azure, GCP, AWS) ermöglicht. Ein Terraform Provider definiert, welche Ressourcentypen von Terraform gemanaged werden können. Terraform Provider werden entweder von HashiCorp selbst, von Plattformen oder von selbstständigen Developern entwickelt. Über <https://registry.terraform.io/browse/providers> kann man sich alle Provider und deren Dokumentation anschauen.

In jedem Konfigurationsfile von Terraform muss ein Provider angegeben werden:

      provider "google" {
        project = "carbide-ego-343511" 
      }

**Terraform State File:**

Wenn man mit Terraform Ressourcen erstellt, speichert Terraform die Informationen darüber im JSON-Format in .tfstate Files. Dieser State wird auch gebraucht, um die vorhandende Infrastruktur mit der geplanten Infrastruktur abzugleichen. Es ist nicht empfohlen, die .tfstate Files manuell zu ändern.

**HasiCorp Configuration Language**

HCL ist eine deklarative Sprache, die für Terraform Konfigurationen gebraucht wird. Die Syntax von HCL ist sehr einfach. 

**Blöcke und Identifier**

Ressourcen werden in Blöcken dargestellt und haben immer einen Namen, der nur von Terraform abgerufen werden kann. Dieser Name kann von anderen Ressourcen referenziert werden. In Terraform heissen diese "Identifier". Um auf die Ressource im Beispiel unten zu referenzieren, wäre das google_compute_instance.mail-host-1.

- Eine Ressource wird immer durch einen Block dargestellt
- Blöcke können auch verschachtelt werden. Siehe den Block network_interface {} im Block resource google_compute_instance {}.

      resource "google_compute_instance" "mail-host-1" {
        name         = "srv-mail1-zh1"
        deletion_protection = true

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
      }

**Argumente**

- In jedem Block arbeitet man mit Argumenten. Diese Argumente beschreiben die Ressource. Argumente haben immer einen Schlüssel und einen Wert. 
- Dabei können Argumente einfache Key/Value Paare sein, es gibt aber auch Key/Array. Also dass ein Schlüssel mehrere Werte haben kann.

Key/Value

        network_ip = "10.60.0.10"

Key/Array

        tags         = ["ssh-server", "server-http", "smtp-server"]

**Input Variablen**

Viele Werte wiederholen sich in Terraform. Um dies zu vereinfachen, gibt es in Terraform auch Variablen. Es gibt dabei viele verschiedene Variablentypen.

Variablen werden mit einem Variablen Block bestimmt. 

      variable "availability_zone_names" {
        type    = list(string)
        default = ["europe-west6-a"]
      }

**Depends_on**

Der Depends_on Block beschreibt Abhängigkeiten im Terraform Konfigurationsfile. Er kann also dazu gebraucht werden, dass z.B. bei der Erstellung einer virtuellen Maschine, welche das Netzwerk "management-zh1" braucht, zuerst gewartet wird, bis dieses Netzwerk erstellt ist.

        depends_on = [
          google_project_service.compute-service,
          google_compute_subnetwork.management-zh1,
          google_compute_subnetwork.production-zh1,
          google_service_account.instance-storage
        ]

### Terraform Befehle

**init**

Mit terraform init bereit man ein Verzeichnis auf das Arbeiten mit Terraform vor. Bevor man init ausführt, sollte im Verzeichnis bereit in .tf Konfigurationsfile liegen. Während init installiert Terraform die benötigten Provider Plugins und bereitet das Backend vor.

**destroy**

Löscht jegliche Infrastruktur, die per Terraform Konfiguration verwaltet wird

**plan**

Mit plan erstellt Terraform ein Plan davon, welche Änderungen Terraform plant durchzuführen. Dabei gleicht Terraform ab, ob die aktuelle Infrastruktur korrekt im aktuellen state erfasst ist. Anschliessend vergleicht Terraform die unterschiedlichen States und schlägt die Änderungen vor, welche es beim apply machen würde.

**apply**

Mit apply wird die Konfiguration die im .tf File angegeben ist ausgeführt und erstellt. Dabei geht Terraform folgendermassen vor: 

- Ressourcen die im aktuellen State gespeichert sind aber nicht in der neuen Konfiguration werden gelöscht.

### Terraform in einem Team

Terraform speichert den aktuellen Stand "state" in einem lokale .tfstate File. Auch die Konfiguration der Infrastruktur wird in einem .tf File lokal gespeichert. Das ist problematisch, wenn man Terraform im Team nutzen möchte. Terraform ermöglicht dabei die Nutzung von Remotestate Files. Diese File können auch gelocked werden.

## Terraform Infrastruktur

Bevor man ein Terraform File entwickeln kann, muss man genau wissen, wie die Zielinfrastruktur aussehen soll.

### Netzwerke

**Management:**

- Name: management
- IP-Range: 10.60.0.0/24
- Subnetze: Management-zh1

**Production:**

- Name: Production
- IP-Range: 10.60.0.0/24
- Subnetze: Management-zh1

### Subnetze

**Management-zh1:**

- Name: management-zh1
- Region: europe-west6
- IP-Range: 10.172.0.0/24
- Gateway: 10.172.0.1

**Production-zh1:**

- Name: production-zh1
- Region: europe-west6
- IP-Range: 10.60.0.0/24
- Gateway: 10.60.0.1

### Firewallregeln

|Name | Netzwerk    | Typ | Ziel (Tag)           | Quelle               | Protokolle |
|-----|-------------|-----|----------------------|----------------------|-----------|
| allow-iap-in-mgm | management  | IN  | ssh-server           | Identity Aware Proxy | tcp:ssh   |
| allow-ssh-in-mgm | management  | IN  | ssh-server           | wireguard-server   | tcp:ssh   |
| allow-vpn-in-mgm | management  | IN  | wireguard-server     | 0.0.0.0/0            | udp:51820 |
| allow-http-in-prod | production  | IN  | entrypoint           | 0.0.0.0/0            | tcp:http  |
| allow-https-in-prod | production  | IN  | entrypoint           | 0.0.0.0/0            | tcp:https |
| allow-smtp-in-prod | production  | IN  | smtp-server          | 0.0.0.0/0            | tcp: 24, 465, 587 |
| allow-proxied-http-in-prod | production  | IN  | server-http  | Proxy-Server         | tcp:http  |
| allow-proxied-https-in-prod | production | IN  | server-https | Proxy-Server         | tcp:https |

### Compute Engine Instanzen

Die Infrastruktur braucht folgende Virtuelle Maschinen:

| Name | Management-IP | Public-IP | PTR-Record | Firewall Tags | Boot Image |
|------|---------------|-----------|------------|---------------|------------|
| srv-proxy-zh1 | 10.172.0.5 | 34.65.164.210 | zuericloud.ch. | entrypoint; ssh-server; wireguard-server; server-http | rhel-cloud/rhel-8 |
| srv-nextcloud-zh1 | 10.172.0.8 | | | ssh-server; server-http | rhel-cloud/rhel-8 |
| srv-mail-zh1 | 10.172.0.10 | 34.65.169.233 | mx1.zuericloud.ch | ssh-server; server-http;  smtp-server | ubuntu-os-cloud/ubuntu-2004-lts

#### Allgmeine Konfiguration

| Machine Type | e2-medium |
|--------------|-----------|
| Zone | europe-west6-a |
| SSH | Public Key |
| Delete Protection | True |
| Secure Boot | True |
| VTPM | True |
| IPV4 | Only |

#### SSH Keys

Sehr wichtig ist die Konfiguration der SSH-Keys auf den Servern. Die SSH Keys stellen sicher, dass der Administrator auf die Zielserver zugreifen kann.

Hierfür kann man den Compute Engine den Public SSH-Key mit Hilfe von Metadaten hinzufügen. 

    metadata = {
      "ssh-keys" = var.ssh
    }

#### Startscript

Die virtuellen Maschinen sollen beim Starten ein Script ausführen. Dieses Script iswwwwwwwwwwwt auf einem Storage Bucket gespeichert. Damit die virtuellen Maschinen auf den Storage Bucket zugreifen können, müssen sie die entsprechende Berechtigung haben. Dazu nutze ich einen Service Account der die Berechtigung "Storage-Objekt-Betrachter" 

    metadata = {
      "ssh-keys" = var.ssh
      "startup-script-url" = "https://storage.cloud.google.com/terraform-init-scripts/test.sh"
    }

## Kubernetes

---

### Kubernetes Architektur

#### Master Node

Die Master Nodes steuern das Cluster an Working Nodes und stellen Tools zur Verwaltung bereit.

**API-Server**

- Kommunikation mit dem Master und den Worker Nodes

Der API-Server ist die Schnittstelle in das Kubernetes Cluster. Die Kubernetes-API ermöglicht, die Erstellung von Deyploments, Replicasets oder Pods über eine REST-API Schnittstelle auf Basis von HTTP.

Der API-Server nimmt HTTP-Anfragen an, kontrolliert, ob diese Richtig sind und führt sie aus. Der Zugriff auf die Kubernetes API funktioniert über das Kommandotool kubectl oder kubeadm. Es gibt auch GUIs für Kubernetes, wie z.B. das offizielle Kubernetes Dashboard.

Der API-Server kommuniziert mit den Worker Nodes mit Kubelet.

**Kube-Scheduler**

- Steuerung der Worker Nodes

Der Kube-Scheduler übernimmt die Steuerung der Container. Er erkennt, wann mehr Container gebraucht werden. Auf welche Node ein Pod deployed werden soll, bestimmt er über die Auslastung.

**Kube-Control-Manager**

- Steuerung der Cluster Controller

KCM steuert verschiedene Controller. Darunter den Replication Controler, Entpoint Configuration, Namespace Controller oder Serviceaccount Controller.

KCM schaut, das der "Current State" im Cluster zum "Desired State" wird.

"In robotics and automation, a control loop is a non-terminal loop that regulates the state of a system."

Beispiel:

Wenn man am Thermostat die Temperatur auf 22° C setzt, dann ist die aktuelle Temperatur der "Current State" (Bspw. 18° C). Die 22° C sind der "Desired State".

![](2022-06-17-09-44-07.png)

**etcd**

- Speicherung der Clusterkonfiguration

etcd ist ein konsitenter, hochverfügbarer und dezentraler Speicher. etcd ist kein Produkt von Kubernetes, sondern eine eigenständige Software.

Alle Daten zum Cluster, also Konfigurationen und Statusinformationen, werden auf einer Schlüsseldatenbank gespeichert. 

https://www.redhat.com/de/topics/containers/what-is-etcd

#### Worker Node

Kubernetes setzt Container in Pods und betreibt diese auf Worker Nodes. In jedem Kubernetes Cluster sollte es mehrere Worker Nodes geben. Worker Nodes können auch geografisch dezentralisiert sein, um die Verfügbarkeit zu erhöhen.

Folgendes muss auf jeder Node installiert werden:

**Kubelet**

Kubelet steuert die Node. Es ist der primäre Node Agent. Er kommuniziert mit der Control Plane. Kubelet führt die Befehle aus, welche vom Control Plane kommen.

**Kubeproxy**

Der Kubeproxy wird auf jeder Worker Node ausgeführt. Der Kubeproxy funktioniert mit Kubernetes Services. Er leitet Anfragen weiter oder verteilt diese.

**Container Runtime** 

Das Container Runtime wird gebraucht, damit Container ausgeführt werden können. Als Beispiele zählen hier Docker oder Containerd.

#### Weitere Bestandtiele

**Persistent Storage**

Persistenter Storage für Kubernetes ist unabhängig von der darunterliegenden physischen Infrastruktur. Für viele Pods wird ein Persistener Speicher gebraucht, welcher die Daten behaltet.

**Container Registry**

Eine Container Registry speichert Images von Containern. Diese Images werden vom Kubernetes Cluster gebraucht, um neue Container zu erstellen. Ein Container Image ist wie das Baumaterial bei einem Haus. Aus dem Material (Image) wird ein funktionierendes Haus (Container)

## Google Cloud Platform

---

Da ich für das Modul M239 die Google Cloud Platform nutze, dokumentiere ich verschiedene Themen auf der GCP, die für diese Arbeit eine Rolle gespielt haben.

### Allgemeines

#### GCP 400$ Kredit

Die Google Cloud Plattform stellt jedem neuen User 300 Dollar Kredit zur verfügung. Wenn man eine Arbeits- oder Schulemail hat, kann man diese ebenfalls nutzen und erhält insgesamt 400 Dollar Kredit. Dieser Kredit ist für 90 Tage gültig.

#### Organisation, Ordner und Projekt

#### Region und Zone

Eine Cloud ist im Endeffekt nur die Computer einer anderen Firma und deren spezialisierte Software. Diese Computer stehen in Rechenzentren, welche über die ganze Welt verteilt sind. GCP teilt ihre Rechenzentren in Regionen und Zonen auf.

- Jede Region besteht aus drei Zonen. Der Namen aus einer Region setzt sich so zusammen: Kontinent-Himmelsrichtung-Nummer
- Jede Zone stellt ein Rechenzentrum dar. Der Namen des Rechenzentrums ist immer der Name der Region plus -a bis -b.

#### Zugriff

GCP stellt verschiedene Möglichkeiten bereit, um damit zu arbeiten und Ressourcen zu steuern und zu verwalten.

**Cloud Console und Cloud Shell:**

Die "Cloud Console" ist das Webinterface für GCP. Es kann über <https://console.cloud.google.com> abgerufen werden. Über das Webinterface lassen sich die meisten APIs steuern und verwalten. Es gibt aber auch Aussnahmen, die man nur über das CLI steuern kann.

Dafür bietet die Cloud Console auch die Cloud Shell an. Cloud Shell ist eine kostenlose Virtuelle Maschine, die sich über den Browser ansprechen lässt. Über die Cloud Shell kann man auf die GCP Infrastruktur zugreifen, aber auch Software entwickeln.

**APIs:**

GCP APIs bieten eine Möglichkeit um über HTTP oder gRPC die Infrastruktur auf GCP zu steuern. Jeder GCP Service hat eine eigene API. So ist die Compute Engine API über <https://compute.googleapis.com> erreichbar. Wenn man über die GCP Cli oder Terraform arbeitet, nutzen diese Tools im Hintergrund ebenfalls die GCP APIs.

**Terraform:**

GCP lässt sich unteranderem auch über Terraform verwalten. Es gibt dafür einen von GCP entwickelten Terraform Provider. Die Dokumentation zum entsprechenden Provider und der Syntax findet man hier: <https://registry.terraform.io/providers/hashicorp/google/latest/docs>

**Cloud SDK und Google Cloud CLI:**

Ein Software Development Kit (SDK) ist eine Sammlung von Werkzeugen und Bibliotheken zur Entwicklung von Software. Über die GCP eigene "Cloud SDK" kann einem bei der entwicklung von Software unterstützen, hat aber auch das Google Cloud CLI inbegriffen. Über die CLI kann man von überall seine Infrastruktur per Command Line Interface verwalten.

Die SDK kann hier heruntergeladen werden: <https://cloud.google.com/sdk/docs/install-sdk?authuser=2&hl=de>

#### APIs

Ein wichtiges Konzept bei GCP sind APIs. Auf GCP ist jeder Service eine API. Sowohl die eigenen Dienste wie GKE oder GCE, aber auch Dienste von externen Anbietern sind APIs. Damit man diesen APIs arbeiten kann, muss man diese aktivieren.

APIs können über Terraform aktiviert und deaktiviert werden:

        resource "google_project_service" "container-service" {
        service = "container.googleapis.com"
        }

Wenn man aber ein neues GCP Projekt erstellt, muss man in diesem zuerst ein Abrechnugskonto hinzufügen, sonst gibt es einen Fehler beim aktivieren der API.