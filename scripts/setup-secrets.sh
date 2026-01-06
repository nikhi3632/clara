#!/bin/bash
set -e

# This script uploads secrets to AWS Parameter Store.
# Run with environment variables set, or edit the values below.
#
# Usage:
#   export LIVEKIT_URL="wss://your-livekit.livekit.cloud"
#   export LIVEKIT_API_KEY="your-api-key"
#   ... (set all variables)
#   ./setup-secrets.sh

echo "Setting up secrets in AWS Parameter Store..."

# Check required environment variables
required_vars=(
    "LIVEKIT_URL"
    "LIVEKIT_API_KEY"
    "LIVEKIT_API_SECRET"
    "LIVEKIT_OUTBOUND_TRUNK_ID"
    "DEEPGRAM_API_KEY"
    "OPENAI_API_KEY"
    "CARTESIA_API_KEY"
    "FOURSQUARE_API_KEY"
    "TWILIO_ACCOUNT_SID"
    "TWILIO_AUTH_TOKEN"
    "TWILIO_PHONE_NUMBER"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set"
        exit 1
    fi
done

# LiveKit
aws ssm put-parameter --name "/clara/LIVEKIT_URL" --value "${LIVEKIT_URL}" --type String --overwrite
aws ssm put-parameter --name "/clara/LIVEKIT_API_KEY" --value "${LIVEKIT_API_KEY}" --type SecureString --overwrite
aws ssm put-parameter --name "/clara/LIVEKIT_API_SECRET" --value "${LIVEKIT_API_SECRET}" --type SecureString --overwrite
aws ssm put-parameter --name "/clara/LIVEKIT_OUTBOUND_TRUNK_ID" --value "${LIVEKIT_OUTBOUND_TRUNK_ID}" --type String --overwrite

# Voice Pipeline
aws ssm put-parameter --name "/clara/DEEPGRAM_API_KEY" --value "${DEEPGRAM_API_KEY}" --type SecureString --overwrite
aws ssm put-parameter --name "/clara/OPENAI_API_KEY" --value "${OPENAI_API_KEY}" --type SecureString --overwrite
aws ssm put-parameter --name "/clara/CARTESIA_API_KEY" --value "${CARTESIA_API_KEY}" --type SecureString --overwrite

# Foursquare
aws ssm put-parameter --name "/clara/FOURSQUARE_API_KEY" --value "${FOURSQUARE_API_KEY}" --type SecureString --overwrite

# Twilio
aws ssm put-parameter --name "/clara/TWILIO_ACCOUNT_SID" --value "${TWILIO_ACCOUNT_SID}" --type SecureString --overwrite
aws ssm put-parameter --name "/clara/TWILIO_AUTH_TOKEN" --value "${TWILIO_AUTH_TOKEN}" --type SecureString --overwrite
aws ssm put-parameter --name "/clara/TWILIO_PHONE_NUMBER" --value "${TWILIO_PHONE_NUMBER}" --type String --overwrite

# Call Redirect (optional)
if [ -n "${CALL_REDIRECT_NUMBER}" ]; then
    aws ssm put-parameter --name "/clara/CALL_REDIRECT_NUMBER" --value "${CALL_REDIRECT_NUMBER}" --type SecureString --overwrite
fi

echo "Secrets created!"
