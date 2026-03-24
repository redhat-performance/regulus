FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    DATA_DIR=/app/data

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy dashboard application with new modular structure
COPY __init__.py ./
COPY app.py ./
COPY data_loader.py ./
COPY aggregator.py ./
COPY run_dashboard.py ./

# Copy new modular structure
COPY services/ ./services/
COPY api/ ./api/

# Copy frontend files
COPY templates/ ./templates/
COPY static/ ./static/

# Create directories for data
RUN mkdir -p /app/data /app/initial_data

# Copy sample data if available (optional - for built-in reports)
COPY docker/sample_data/ /tmp/sample_data_temp/
RUN if [ -n "$(ls -A /tmp/sample_data_temp/*.json 2>/dev/null)" ]; then \
      cp /tmp/sample_data_temp/*.json /app/initial_data/ 2>/dev/null || true; \
    fi && rm -rf /tmp/sample_data_temp

# Copy wrapper script
COPY docker/run_wrapper.sh ./run_wrapper.sh
RUN chmod +x run_wrapper.sh

# Copy entrypoint script
COPY docker/entrypoint.sh ./entrypoint.sh
RUN chmod +x entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["python", "run_dashboard.py", "--reports", "/app/data", "--host", "0.0.0.0", "--port", "5000"]
