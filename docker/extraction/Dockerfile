FROM python:3.12-slim

WORKDIR /app

# Install system dependencies for psycopg2-binary
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy MLB-StatsAPI local dependency first (for layer caching)
COPY MLB-StatsAPI/ /app/MLB-StatsAPI/

# Copy project files
COPY pyproject.toml /app/
COPY config.docker.yml /app/config.yml
COPY scripts/ /app/scripts/
COPY main.py /app/

# Install dependencies using pip (no uv in container)
RUN pip install --no-cache-dir . && \
    pip install --no-cache-dir ./MLB-StatsAPI

# Create logs directory
RUN mkdir -p /app/logs

ENTRYPOINT ["python", "main.py"]
