FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    DATA_DIR=/app/data

WORKDIR /app

# Install dependencies
COPY dashboard/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy dashboard application with new modular structure
COPY dashboard/__init__.py ./
COPY dashboard/app.py ./
COPY dashboard/data_loader.py ./
COPY dashboard/aggregator.py ./
COPY dashboard/run_dashboard.py ./

# Copy new modular structure
COPY dashboard/services/ ./services/
COPY dashboard/api/ ./api/

# Copy frontend files
COPY dashboard/templates/ ./templates/
COPY dashboard/static/ ./static/

# Create directories for data
RUN mkdir -p /app/data /app/initial_data

# Copy built-in reports from generated/ directory (optional - for built-in reports)
# Build context is now REPORT/, so generated/ is accessible
COPY generated /tmp/generated_temp
RUN if [ -d "/tmp/generated_temp" ] && [ -n "$(ls -A /tmp/generated_temp/*.json 2>/dev/null)" ]; then \
      cp /tmp/generated_temp/*.json /app/initial_data/ 2>/dev/null || true; \
    fi && rm -rf /tmp/generated_temp

# Copy wrapper script
COPY dashboard/docker/run_wrapper.sh ./run_wrapper.sh
RUN chmod +x run_wrapper.sh

# Copy entrypoint script
COPY dashboard/docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["sh", "-c", "python run_dashboard.py --reports /app/data --host 0.0.0.0 ${PORT:+--port $PORT}"]
