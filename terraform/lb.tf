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

# Cloud Armor Security Policy for TCP/SSL Proxy (or backend)
resource "google_compute_security_policy" "mqtt_armor" {
  name = "mqtt-armor-policy"

  # Basic deny all
  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default deny"
  }

  # Allow specific IPs (example logic, modify as needed)
  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["0.0.0.0/0"] # Change this to allow-listed IPs
      }
    }
    description = "Allow all for testing"
  }
}

# Backend Service for the MIG
resource "google_compute_backend_service" "mqtt_backend_svc" {
  name                  = "mqtt-backend-svc"
  protocol              = "TCP"
  port_name             = "mqtt"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 600
  health_checks         = [google_compute_health_check.mqtt_hc.id]
  security_policy       = google_compute_security_policy.mqtt_armor.id

  backend {
    group                        = google_compute_region_instance_group_manager.mqtt_mig.instance_group
    balancing_mode               = "CONNECTION"
    max_connections_per_instance = 100000
  }
}

# Target SSL Proxy
resource "google_compute_target_ssl_proxy" "mqtt_ssl_proxy" {
  name             = "mqtt-ssl-proxy"
  backend_service  = google_compute_backend_service.mqtt_backend_svc.id
  ssl_certificates = [google_compute_ssl_certificate.mqtt_cert.id]
}

# Global Forwarding Rule for SSL (Port 8883 is standard for secure MQTT)
resource "google_compute_global_forwarding_rule" "mqtt_forwarding_rule" {
  name                  = "mqtt-forwarding-rule"
  target                = google_compute_target_ssl_proxy.mqtt_ssl_proxy.id
  port_range            = "8883"
  load_balancing_scheme = "EXTERNAL"
}

# SSL Certificate for the Proxy
resource "google_compute_ssl_certificate" "mqtt_cert" {
  name_prefix = "mqtt-lb-cert-"
  private_key = var.tls_key
  certificate = var.tls_cert

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate Manager TrustConfig for mTLS
resource "google_certificate_manager_trust_config" "mqtt_trust_config" {
  name        = "mqtt-mtls-trust-config"
  description = "Trust config for MQTT mTLS"
  location    = "global"

  trust_stores {
    trust_anchors {
      pem_certificate = var.ca_cert_pem
    }
  }
}

# Note: Attaching mTLS to Target SSL Proxy requires Edge Security Policy or Server TLS Policy in newer provider versions.
# For simplicity in this spec, we will output instructions to attach it, or use the beta provider if supported.
