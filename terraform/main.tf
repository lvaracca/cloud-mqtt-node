# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# --- Shared Variables & Locals ---
locals {
  network_name = "mqtt-vpc"
  subnet_name  = "mqtt-subnet"
}

# --- Network ---
resource "google_compute_network" "vpc" {
  name                    = local.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = local.subnet_name
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Cloud Router + NAT for Outbound Internet (to pull images / communicate with PubSub)
resource "google_compute_router" "router" {
  name    = "mqtt-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "mqtt-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  enable_dynamic_port_allocation = true
  min_ports_per_vm               = 8192
  max_ports_per_vm               = 65536
}

# Firewall for Health Checks and Load Balancer
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "allow-lb-hc"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["1883", "8883"]
  }
  # Ranges for GCP health checks & load balancers (Proxy IPs) plus allow all because
  # Cloud Armor does the actual filtering, but VPC needs to let the traffic in.
  source_ranges = ["0.0.0.0/0"]
}

# Allow SSH from IAP
resource "google_compute_firewall" "allow_iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

# --- Pub/Sub Service Identity & Permissions ---
# Retrieve the Pub/Sub service agent email
resource "google_project_service_identity" "pubsub_agent" {
  provider = google-beta
  service  = "pubsub.googleapis.com"
  project  = var.project_id
}

# Grant the Pub/Sub service agent permission to write to BigQuery
resource "google_project_iam_member" "pubsub_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_project_service_identity.pubsub_agent.email}"
}

resource "google_project_iam_member" "pubsub_bq_viewer" {
  project = var.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_project_service_identity.pubsub_agent.email}"
}
