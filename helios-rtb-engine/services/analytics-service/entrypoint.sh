#!/bin/bash
# Entrypoint script for analytics service

set -e

echo "Analytics Service - Starting"

# Wait for database to be ready
echo "Waiting for PostgreSQL..."
until PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is up - continuing"

# Run migrations
echo "Running database migrations..."
python manage.py migrate --noinput

# Create superuser if needed (optional, for development)
if [ "$DJANGO_SUPERUSER_USERNAME" ] && [ "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "Creating superuser..."
    python manage.py shell <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
    User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD')
    print('Superuser created')
else:
    print('Superuser already exists')
EOF
fi

# Start the application based on command
if [ "$1" = "api" ]; then
    echo "Starting API server..."
    exec gunicorn analytics.wsgi:application \
        --bind 0.0.0.0:8000 \
        --workers 4 \
        --access-logfile - \
        --error-logfile -
elif [ "$1" = "consumer" ]; then
    echo "Starting Kafka consumer..."
    exec python manage.py process_outcomes
elif [ "$1" = "shell" ]; then
    exec python manage.py shell
else
    # Default: run the provided command
    exec "$@"
fi
