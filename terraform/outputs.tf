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

output "mqtt_public_ip" {
  description = "Public IP Address of the MQTT Global Load Balancer"
  value       = google_compute_global_forwarding_rule.mqtt_forwarding_rule.ip_address
}

output "pubsub_topic" {
  description = "The Pub/Sub topic where messages are ingested"
  value       = google_pubsub_topic.mqtt_topic.name
}

output "bigquery_table" {
  description = "The BigQuery table landing the messages"
  value       = "${google_bigquery_dataset.bq_dataset.dataset_id}.${google_bigquery_table.bq_table.table_id}"
}
