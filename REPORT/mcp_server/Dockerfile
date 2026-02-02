FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy MCP server and CLI
COPY regulus_es_mcp.py .
COPY es_cli.py .
COPY es_show_keywords.py .

# Make scripts executable
RUN chmod +x es_cli.py es_show_keywords.py

# Set entrypoint to CLI
ENTRYPOINT ["python", "es_cli.py"]
CMD ["--help"]
