FROM python:3.12-slim

WORKDIR /dbt

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Install dbt-postgres
RUN pip install --no-cache-dir dbt-core dbt-postgres

# Copy dbt project files
COPY dbt_mlb/ /dbt/

# Install dbt packages
RUN dbt deps --project-dir /dbt --profiles-dir /dbt

# Default: run dbt
ENTRYPOINT ["dbt"]
CMD ["run", "--project-dir", "/dbt", "--profiles-dir", "/dbt"]
