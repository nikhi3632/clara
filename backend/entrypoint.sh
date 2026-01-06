#!/bin/bash
set -e

# Fetch secrets from AWS Parameter Store if running in AWS
if [ -n "$AWS_REGION" ]; then
    echo "Fetching secrets from Parameter Store..."

    # LiveKit
    export LIVEKIT_URL=$(aws ssm get-parameter --name "/clara/LIVEKIT_URL" --query "Parameter.Value" --output text)
    export LIVEKIT_API_KEY=$(aws ssm get-parameter --name "/clara/LIVEKIT_API_KEY" --with-decryption --query "Parameter.Value" --output text)
    export LIVEKIT_API_SECRET=$(aws ssm get-parameter --name "/clara/LIVEKIT_API_SECRET" --with-decryption --query "Parameter.Value" --output text)
    export LIVEKIT_OUTBOUND_TRUNK_ID=$(aws ssm get-parameter --name "/clara/LIVEKIT_OUTBOUND_TRUNK_ID" --query "Parameter.Value" --output text)

    # Voice Pipeline
    export DEEPGRAM_API_KEY=$(aws ssm get-parameter --name "/clara/DEEPGRAM_API_KEY" --with-decryption --query "Parameter.Value" --output text)
    export OPENAI_API_KEY=$(aws ssm get-parameter --name "/clara/OPENAI_API_KEY" --with-decryption --query "Parameter.Value" --output text)
    export CARTESIA_API_KEY=$(aws ssm get-parameter --name "/clara/CARTESIA_API_KEY" --with-decryption --query "Parameter.Value" --output text)

    # Foursquare
    export FOURSQUARE_API_KEY=$(aws ssm get-parameter --name "/clara/FOURSQUARE_API_KEY" --with-decryption --query "Parameter.Value" --output text)

    # Twilio
    export TWILIO_ACCOUNT_SID=$(aws ssm get-parameter --name "/clara/TWILIO_ACCOUNT_SID" --with-decryption --query "Parameter.Value" --output text)
    export TWILIO_AUTH_TOKEN=$(aws ssm get-parameter --name "/clara/TWILIO_AUTH_TOKEN" --with-decryption --query "Parameter.Value" --output text)
    export TWILIO_PHONE_NUMBER=$(aws ssm get-parameter --name "/clara/TWILIO_PHONE_NUMBER" --query "Parameter.Value" --output text)

    # Call Redirect
    export CALL_REDIRECT_NUMBER=$(aws ssm get-parameter --name "/clara/CALL_REDIRECT_NUMBER" --with-decryption --query "Parameter.Value" --output text)
    export CALL_REDIRECT_ENABLED=${CALL_REDIRECT_ENABLED:-true}

    echo "Secrets loaded."
fi

exec python main.py "$@"
