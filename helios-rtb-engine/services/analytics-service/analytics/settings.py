"""
Django settings for analytics service.
Generated for Helios RTB Engine - Analytics Service
"""

import os
import sys
from pathlib import Path

from typing import cast

import environ
from django.core.exceptions import ImproperlyConfigured

# Build paths inside the project
BASE_DIR = Path(__file__).resolve().parent.parent

# Initialize environment variables
env = environ.Env(
    DEBUG=(bool, False),
    ALLOWED_HOSTS=(list, ['*']),
)

# Read .env file if it exists
env_file = os.path.join(BASE_DIR, '.env')
if os.path.exists(env_file):
    environ.Env.read_env(env_file)


def get_env_str(name: str, fallback: str) -> str:
    try:
        return cast(str, env.str(name))
    except ImproperlyConfigured:
        return fallback


def get_env_bool(name: str, fallback: bool) -> bool:
    try:
        return cast(bool, env.bool(name))
    except ImproperlyConfigured:
        return fallback


def get_env_int(name: str, fallback: int) -> int:
    try:
        return cast(int, env.int(name))
    except ImproperlyConfigured:
        return fallback


def get_env_list(name: str, fallback: list[str]) -> list[str]:
    try:
        return cast(list[str], env.list(name))
    except ImproperlyConfigured:
        return fallback

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = get_env_str('DJANGO_SECRET_KEY', 'django-insecure-dev-key-change-in-production')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = get_env_bool('DEBUG', False)

ALLOWED_HOSTS = get_env_list('ALLOWED_HOSTS', ['*'])

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'outcomes',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'analytics.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'analytics.wsgi.application'

# Database
# https://docs.djangoproject.com/en/5.0/ref/settings/#databases
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
    'NAME': get_env_str('DB_NAME', 'helios_analytics'),
    'USER': get_env_str('DB_USER', 'postgres'),
    'PASSWORD': get_env_str('DB_PASSWORD', 'postgres'),
    'HOST': get_env_str('DB_HOST', 'localhost'),
    'PORT': get_env_int('DB_PORT', 5432),
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = 'static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Django REST Framework
REST_FRAMEWORK = {
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 100,
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    'DEFAULT_FILTER_BACKENDS': [
        'rest_framework.filters.OrderingFilter',
    ],
    'ORDERING': ['-timestamp'],
}

# Kafka Configuration
KAFKA_BROKERS = get_env_str('KAFKA_BROKERS', 'localhost:9092')
KAFKA_TOPIC_AUCTION_OUTCOMES = get_env_str('KAFKA_TOPIC_AUCTION_OUTCOMES', 'auction_outcomes')
KAFKA_CONSUMER_GROUP = get_env_str('KAFKA_CONSUMER_GROUP', 'analytics-service-group')

# Logging Configuration
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'json': {
            'format': '{"timestamp": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s", "module": "%(module)s"}',
            'datefmt': '%Y-%m-%dT%H:%M:%S%z',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'json',
            'stream': sys.stdout,
        },
    },
    'root': {
        'handlers': ['console'],
    'level': get_env_str('LOG_LEVEL', 'INFO'),
    },
}

# Cross-Origin Resource Sharing (CORS)
CORS_ALLOW_ALL_ORIGINS = get_env_bool('CORS_ALLOW_ALL_ORIGINS', False)
CORS_ALLOWED_ORIGINS = get_env_list(
    'CORS_ALLOWED_ORIGINS',
    [
        'http://localhost:3000',
        'http://127.0.0.1:3000',
    ],
)
CORS_ALLOW_CREDENTIALS = get_env_bool('CORS_ALLOW_CREDENTIALS', False)
