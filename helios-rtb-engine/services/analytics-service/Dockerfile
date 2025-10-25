# syntax=docker/dockerfile:1

# Build stage
FROM python:3.12-slim AS build
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt ./
RUN pip install --user --no-cache-dir -r requirements.txt

# Copy application code
COPY manage.py ./
COPY analytics ./analytics
COPY outcomes ./outcomes
COPY entrypoint.sh ./

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Collect static files
ENV DJANGO_SETTINGS_MODULE=analytics.settings
RUN python manage.py collectstatic --noinput || true

# Production stage
FROM python:3.12-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 django && \
    mkdir -p /app /app/staticfiles && \
    chown -R django:django /app

WORKDIR /app
USER django

# Copy from build stage
COPY --from=build --chown=django:django /root/.local /home/django/.local
COPY --from=build --chown=django:django /app ./

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Add local bin to PATH
ENV PATH=/home/django/.local/bin:$PATH
ENV PYTHONPATH=/app
ENV DJANGO_SETTINGS_MODULE=analytics.settings

# Expose port
EXPOSE 8000

# Set entrypoint
ENTRYPOINT ["./entrypoint.sh"]

# Default command
CMD ["api"]
