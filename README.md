# Vaxiil - SaaS Wellness Platform

A comprehensive SaaS platform for wellness services including massage, therapy, and room rentals with privacy-focused features.

## Features

- Multi-tenancy with organization-based data isolation
- Soft delete functionality with global unique constraints
- UUID primary keys for all models
- Trust alias system for privacy
- KYC/KYB verification framework
- Geo-based service discovery
- Escrow payment system
- Real-time messaging (Django Channels)

## Tech Stack

- **Backend**: Django + Django REST Framework
- **Database**: PostgreSQL with GeoDjango
- **Package Manager**: uv with pyproject.toml
- **Authentication**: JWT
- **Real-time**: Django Channels + Redis
- **Payments**: Stripe integration
- **Frontend**: Django Admin (interim) → Flutter (future)

## Project Structure

```
backend/
├── src/
│   ├── config/
│   │   ├── settings/
│   │   │   ├── base.py
│   │   │   ├── development.py
│   │   │   ├── production.py
│   │   │   └── test.py
│   │   ├── urls.py
│   │   ├── wsgi.py
│   │   └── asgi.py
│   └── apps/
│       ├── core/
│       ├── organizations/
│       ├── users/
│       ├── services/
│       ├── bookings/
│       └── payments/
├── manage.py
└── pyproject.toml
```

## Setup

1. Install dependencies:
```bash
uv sync
```

2. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. Run migrations:
```bash
python backend/manage.py migrate
```

4. Create superuser:
```bash
python backend/manage.py createsuperuser
```

5. Start development server:
```bash
python backend/manage.py runserver
```

## Code Quality

Pre-commit hooks are configured for:
- Black (code formatting)
- Ruff (linting and formatting)
- Flake8 (linting)
- Django-upgrade (version compatibility)

## Development

The project follows these conventions:
- 120 character line limit
- UUID primary keys
- Soft delete with `deleted_at` field
- Multi-tenancy via `organization` foreign key
- Comprehensive test coverage

## License

Proprietary
