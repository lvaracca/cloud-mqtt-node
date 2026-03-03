# Architecture

## Overview

The Cloud MQTT Node is a cloud-native architecture designed to ingest high-throughput MQTT messages from IoT devices and stream them directly into BigQuery for analytics.

## Components

### 1. Load Balancer (Global External TCP/SSL Proxy)
-   **Public Interface**: Listens on port **8883** (Secure MQTT).
-   **Security**: Terminates SSL/TLS connections at the edge.
-   **mTLS**: Validates client certificates against a TRUST config before traffic reaches the backend.
-   **Cloud Armor**: Provides DDoS protection and IP allowlisting/denylisting.

### 2. Compute Engine (MIG)
-   **Managed Instance Group**: A group of VMs running the MQTT Bridge.
    -   *Architectural Choice*: We use a MIG rather than Cloud Run or GKE because Cloud Run does not currently support raw TCP traffic with long-lived persistent connections efficiently (it is HTTP-centric), and GKE introduces unnecessary operational overhead for a single container. A simple MIG provides the best balance of TCP support, auto-healing, and simplicity.
    -   *Scalability Limit*: Because this implementation uses an in-memory Mosquitto broker to manage the client connections before forwarding to Pub/Sub, the MIG size is **fixed to 1 instance**. It cannot auto-scale horizontally without introducing a shared state layer (like Redis or a clustered MQTT broker).
    -   *VM Sizing*: We default to an `e2-medium` (2 vCPU, 4GB RAM) which is highly capable for this workload.
-   **Internal Interface**: Listens on port **1883** (Not exposed publicly).
-   **Containerized**: Runs the custom Go bridge application as a Docker container.
-   **Service Account**: Uses the Compute Engine Service Account with minimal permissions (Pub/Sub Publisher, Logging).

### 3. MQTT Bridge (Go Application)
-   **Protocol**: MQTT 3.1.1 / 5.0 compatible.
-   **Library**: Uses `eclipse/paho.mqtt.golang` for robust MQTT handling.
-   **Logic**:
    -   Subscribes to `#` (all topics) or configured wildcards.
    -   Validates message payload (JSON).
    -   Publishes messages to Cloud Pub/Sub asynchronously.

### 4. Cloud Pub/Sub
-   **Topic**: `mqtt-topic` receives all valid messages.
-   **Buffer**: Decouples ingestion from processing, allowing for traffic spikes.

### 5. BigQuery
-   **Subscription**: A BigQuery Subscription (`mqtt-bq-sub`) directly writes from Pub/Sub to the `mqtt_messages` table.
-   **Schema**:
    -   `topic` (STRING): The MQTT topic name.
    -   `payload` (JSON/STRING): The message content.
    -   `timestamp` (TIMESTAMP): Ingestion time.
    -   `device_id` (STRING): Extracted from client certificate or topic path.

## Data Flow

1.  **IoT Device** connects to `mqtt.example.com:8883` using a Client Certificate.
2.  **Load Balancer** verifies the certificate. If valid, forwards connection to a backend VM.
3.  **Bridge App** accepts the connection (acting as an MQTT broker/client) and subscribes to data topics.
4.  **Device** publishes a payload `{"temp": 25}` to `sensors/temp`.
5.  **Bridge App** receives the message and publishes it to Pub/Sub topic `mqtt-topic`.
6.  **Pub/Sub** pushes the message to BigQuery via the subscription.
7.  **Data** is available in BigQuery for analysis instantly.
