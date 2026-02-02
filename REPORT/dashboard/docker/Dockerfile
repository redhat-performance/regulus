FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    DATA_DIR=/app/data

WORKDIR /app

# Install dependencies
COPY docker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy dashboard application (from build context root, excluding docker/)
COPY *.py ./dashboard/
COPY templates/ ./dashboard/templates/
COPY static/ ./dashboard/static/

# Create directories for data
RUN mkdir -p /app/data /app/initial_data

# Copy sample data directory (which may be empty)
COPY docker/sample_data/ /tmp/sample_data/

# Move any JSON files to initial_data (if they exist)
RUN if [ -n "$(ls -A /tmp/sample_data/*.json 2>/dev/null)" ]; then \
        mv /tmp/sample_data/*.json /app/initial_data/; \
    fi && \
    rm -rf /tmp/sample_data

# Copy Python wrapper script that bypasses interactive prompts
COPY docker/run_wrapper.sh ./run_wrapper.py
RUN chmod +x run_wrapper.py

# Copy entrypoint script
COPY docker/entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["python", "run_wrapper.py"]

