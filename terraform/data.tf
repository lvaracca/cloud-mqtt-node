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

# Pub/Sub Topic
resource "google_pubsub_topic" "mqtt_topic" {
  name = var.pubsub_topic_name
}

# BigQuery Dataset
resource "google_bigquery_dataset" "bq_dataset" {
  dataset_id                  = var.bq_dataset_name
  friendly_name               = "MQTT Landing Dataset"
  description                 = "Dataset for MQTT ingested messages"
  location                    = var.region
  # default_table_expiration_ms = 3600000 # 1 hour for testing, adjust as needed
}

# BigQuery Table
resource "google_bigquery_table" "bq_table" {
  dataset_id = google_bigquery_dataset.bq_dataset.dataset_id
  table_id   = var.bq_table_name

  schema = <<EOF
[
  {
    "name": "data",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Message payload"
  },
  {
    "name": "publish_time",
    "type": "TIMESTAMP",
    "mode": "REQUIRED",
    "description": "Pub/Sub message publish time"
  },
  {
    "name": "message_id",
    "type": "STRING",
    "mode": "REQUIRED",
    "description": "Pub/Sub message ID"
  },
  {
    "name": "attributes",
    "type": "JSON",
    "mode": "NULLABLE",
    "description": "Message attributes (e.g. mqtt_topic)"
  },
  {
    "name": "subscription_name",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "Subscription name"
  }
]
EOF
}

# Pub/Sub Subscription to BigQuery
resource "google_pubsub_subscription" "bq_subscription" {
  name  = "${var.pubsub_topic_name}-bq-sub"
  topic = google_pubsub_topic.mqtt_topic.name

  bigquery_config {
    table = "${var.project_id}.${google_bigquery_dataset.bq_dataset.dataset_id}.${google_bigquery_table.bq_table.table_id}"
    use_topic_schema = false
    write_metadata   = true # This automatically writes publish_time and message_id
  }

  depends_on = [
    google_bigquery_table.bq_table,
    google_project_iam_member.pubsub_bq_writer
  ]
}

# Grant Pub/Sub Service Account permission to write to BigQuery
data "google_project" "project" {}

resource "google_project_iam_member" "pubsub_bq_writer" {
  project = data.google_project.project.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
