// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cloud.google.com/go/pubsub"
	mqtt "github.com/eclipse/paho.mqtt.golang"
)

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func main() {
	projectID := getEnv("GCP_PROJECT_ID", "")
	topicID := getEnv("GCP_PUBSUB_TOPIC", "mqtt-topic")
	mqttBroker := getEnv("MQTT_BROKER", "tcp://localhost:1883")
	mqttClientID := getEnv("MQTT_CLIENT_ID", "go-bridge")

	if projectID == "" {
		log.Fatal("GCP_PROJECT_ID environment variable must be set")
	}

	ctx := context.Background()
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create Pub/Sub client: %v", err)
	}
	defer client.Close()

	topic := client.Topic(topicID)
	// Enable high-throughput batching settings for the Pub/Sub producer.
	topic.PublishSettings.ByteThreshold = 5000000     // 5MB batch
	topic.PublishSettings.CountThreshold = 1000       // Max 1000 messages per batch
	topic.PublishSettings.DelayThreshold = 50 * time.Millisecond // 50ms max delay
	topic.PublishSettings.NumGoroutines = 10          // allow up to 10 concurrent streams to PubSub

	defer topic.Stop()

	opts := mqtt.NewClientOptions().AddBroker(mqttBroker).SetClientID(mqttClientID)
	opts.SetAutoReconnect(true)
	opts.SetCleanSession(false)
	// Disable Auto ACK so we can ACK manually when Pub/Sub is confirmed
	opts.SetAutoAckDisabled(true)

	// Message handler
	var messagePubHandler mqtt.MessageHandler = func(client mqtt.Client, msg mqtt.Message) {
		// Publish to Pub/Sub
		res := topic.Publish(ctx, &pubsub.Message{
			Data: msg.Payload(),
			Attributes: map[string]string{
				"mqtt_topic": msg.Topic(),
			},
		})

		// Wait for publish to succeed in a goroutine so we don't block the MQTT client's network loop
		go func(r *pubsub.PublishResult, m mqtt.Message) {
			_, err := r.Get(ctx)
			if err != nil {
				log.Printf("Failed to publish message to Pub/Sub: %v", err)
				// We do not call m.Ack(). This allows Mosquitto to resend the message
				// based on QoS 1 retry logic.
				return
			}
			m.Ack()
		}(res, msg)
	}

	opts.SetDefaultPublishHandler(messagePubHandler)
	opts.SetOnConnectHandler(func(c mqtt.Client) {
		log.Println("Connected to MQTT broker. Subscribing to #")
		// Subscribe with QoS 1
		if token := c.Subscribe("#", 1, nil); token.Wait() && token.Error() != nil {
			log.Printf("Error subscribing: %v", token.Error())
		}
	})
	opts.SetConnectionLostHandler(func(c mqtt.Client, err error) {
		log.Printf("Connection lost: %v", err)
	})

	mqttClient := mqtt.NewClient(opts)
	if token := mqttClient.Connect(); token.Wait() && token.Error() != nil {
		log.Fatalf("Failed to connect to MQTT broker: %v", token.Error())
	}
	defer mqttClient.Disconnect(250)

	// Wait for termination signal
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	log.Println("Bridge is running. Waiting for messages.")
	<-sigs
	log.Println("Shutting down bridge...")
}
