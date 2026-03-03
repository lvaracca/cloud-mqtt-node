#!/bin/bash
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

set -e

echo "=========================================="
echo "   Cloud MQTT Node - Quick Deployment   "
echo "=========================================="
echo ""

# 1. Check prerequisites
echo "Checking prerequisites..."
MISSING_TOOLS=()
for cmd in git gcloud terraform; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_TOOLS+=("$cmd")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "ERROR: The following tools are missing: ${MISSING_TOOLS[*]}"
    echo "Please install them before continuing."
    exit 1
fi
echo "Prerequisites OK."
echo ""

# 2. Project configuration
if [ -z "$GCP_PROJECT_ID" ]; then
    # Try to get the default gcloud project
    DEFAULT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -n "$DEFAULT_PROJECT" ]; then
        read -p "Enter your GCP Project ID [$DEFAULT_PROJECT]: " INPUT_PROJECT
        export GCP_PROJECT_ID=${INPUT_PROJECT:-$DEFAULT_PROJECT}
    else
        read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
        export GCP_PROJECT_ID
    fi
fi

if [ -z "$GCP_REGION" ]; then
    read -p "Enter your GCP Region [us-central1]: " INPUT_REGION
    export GCP_REGION=${INPUT_REGION:-us-central1}
fi

echo ""
echo "Configuration:"
echo "- GCP Project : $GCP_PROJECT_ID"
echo "- Region      : $GCP_REGION"
echo ""

# 3. Fetch source code
# Replace the repository URL below with the public or private URL of your Git repository
REPO_URL="https://github.com/lvaracca/cloud-mqtt-node.git"
DEST_DIR="cloud-mqtt-node"

if [ ! -d "$DEST_DIR" ]; then
    echo "Downloading source code..."
    git clone "$REPO_URL" "$DEST_DIR"
else
    echo "Directory $DEST_DIR already exists. Updating..."
    cd "$DEST_DIR"
    git pull
    cd ..
fi

cd "$DEST_DIR"

# 4. Authentication (if not logged in)
if ! gcloud auth print-access-token &> /dev/null; then
    echo "You must authenticate to Google Cloud."
    echo "Please follow the link below to authenticate from any browser, then paste the authorization code here:"
    gcloud auth login --no-browser
fi

gcloud config set project "$GCP_PROJECT_ID"

# 5. Certificates
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo ""
    read -p "Do you want to generate self-signed certificates for testing? [Y/n] " gen_certs
    if [[ ! "$gen_certs" =~ ^[Nn]$ ]]; then
        bash ./generate_certs.sh
    else
        echo "⚠️ Note: You will need to manually configure terraform/terraform.tfvars."
    fi
fi

# 6. Run main init script
echo ""
echo "Starting deployment..."
chmod +x ./init
bash ./init

echo ""
echo "=========================================="
echo "          Deployment Complete!            "
echo "=========================================="
