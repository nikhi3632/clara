FROM python:3.13.1-slim

WORKDIR /app

# Install AWS CLI for SSM parameter fetching
RUN apt-get update && apt-get install -y awscli && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Health check port
EXPOSE 8080

# Use entrypoint to fetch secrets from Parameter Store
ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
