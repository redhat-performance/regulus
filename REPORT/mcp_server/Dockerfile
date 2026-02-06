FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy ES integration config module (shared configuration)
COPY ../es_integration/es_config.py es_integration/

# Copy MCP server and CLI
COPY regulus_es_mcp.py .
COPY es_cli.py .
COPY es_show_keywords.py .

# Make scripts executable
RUN chmod +x es_cli.py es_show_keywords.py

# Set entrypoint to CLI
# Users provide ES_URL via: docker run -e ES_URL='https://user:pass@host' regulus-es-cli list-batches
ENTRYPOINT ["python", "es_cli.py"]
CMD ["--help"]
