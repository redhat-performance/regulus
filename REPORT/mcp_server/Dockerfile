FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY mcp_server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy ES integration config module (shared configuration)
# Build context is REPORT directory, so paths are relative to REPORT/
RUN mkdir -p es_integration
COPY es_integration/es_config.py es_integration/

# Copy MCP server and CLI
COPY mcp_server/regulus_es_mcp.py .
COPY mcp_server/es_cli.py .
COPY mcp_server/es_show_keywords.py .

# Make scripts executable
RUN chmod +x es_cli.py es_show_keywords.py

# Set entrypoint to CLI
# Users provide ES_URL via: docker run -e ES_URL='https://user:pass@host' regulus-es-cli list-batches
ENTRYPOINT ["python", "es_cli.py"]
CMD ["--help"]
