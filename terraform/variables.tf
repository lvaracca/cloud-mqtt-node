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

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "bq_dataset_name" {
  description = "BigQuery dataset name"
  type        = string
  default     = "mqtt_bridge_data"
}

variable "bq_table_name" {
  description = "BigQuery landing table name"
  type        = string
  default     = "mqtt_messages"
}

variable "pubsub_topic_name" {
  description = "Pub/Sub topic for MQTT messages"
  type        = string
  default     = "mqtt-topic"
}

variable "bridge_image" {
  description = "Container image for the Go Bridge sidecar"
  type        = string
  # No default - force user/script to provide it
}

variable "ca_cert_pem" {
  description = "PEM encoded CA certificate for mTLS TrustConfig"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the MQTT broker (must match certificate)"
  type        = string
}

variable "tls_cert" {
  description = "Server TLS Certificate for the LB"
  type        = string
}

variable "tls_key" {
  description = "Server TLS Private Key for the LB"
  type        = string
}
