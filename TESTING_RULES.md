# Testing Rules and Structure

## 📋 Overview

This document outlines the testing structure and rules for the Vaxiil project. All tests should be organized in dedicated `tests/` folders within each app.

## 🏗️ Test Structure

### Directory Structure
```
backend/src/apps/
├── core/
│   ├── models.py
│   └── tests.py
├── organizations/
│   ├── models/
│   │   ├── __init__.py
│   │   └── organization.py
│   ├── admin.py
│   └── tests/
│       ├── __init__.py
│       ├── test_models.py
│       ├── test_admin.py
│       └── test_views.py
├── services/
│   ├── models/
│   │   ├── __init__.py
│   │   ├── category.py
│   │   ├── service.py
│   │   ├── media.py
│   │   ├── features.py
│   │   └── organization_subcategory.py
│   ├── admin.py
│   └── tests/
│       ├── __init__.py
│       ├── test_models.py
│       ├── test_admin.py
│       ├── test_availability.py
│       └── test_views.py
├── users/
│   ├── models.py
│   ├── admin.py
│   └── tests/
│       ├── __init__.py
│       ├── test_models.py
│       ├── test_admin.py
│       └── test_views.py
└── bookings/
    ├── models/
    │   ├── __init__.py
    │   ├── models.py
    │   ├── cancellation_models.py
    │   └── analytics_models.py
    ├── admin.py
    └── tests/
        ├── __init__.py
        ├── test_models.py
        ├── test_admin.py
        └── test_views.py
```

## 📝 Test File Naming Conventions

### Test Files
- `test_models.py` - Model tests
- `test_admin.py` - Admin interface tests
- `test_views.py` - View/API tests
- `test_forms.py` - Form tests
- `test_utils.py` - Utility function tests
- `test_integration.py` - Integration tests

### Test Classes
- Use descriptive class names ending with `Tests`
- Example: `ServiceModelTests`, `OrganizationAdminTests`

### Test Methods
- Use descriptive method names starting with `test_`
- Example: `test_service_creation()`, `test_organization_str_representation()`

## 🎯 Testing Requirements

### Model Tests
Each model should have tests for:
- ✅ **Creation**: Test model creation with valid data
- ✅ **String Representation**: Test `__str__` method
- ✅ **Properties**: Test custom properties and methods
- ✅ **Constraints**: Test unique constraints and validations
- ✅ **Relationships**: Test foreign key and many-to-many relationships
- ✅ **Choices**: Test TextChoices and field choices
- ✅ **Indexes**: Test that indexes work correctly (if applicable)

### Admin Tests
Each admin class should have tests for:
- ✅ **List Display**: Test `list_display` fields
- ✅ **Search Fields**: Test `search_fields`
- ✅ **List Filters**: Test `list_filter`
- ✅ **Fieldsets**: Test fieldset organization
- ✅ **Custom Actions**: Test custom admin actions (if any)

### AvailabilityMixin Tests
Since AvailabilityMixin is used across multiple models:
- ✅ **Day Choices**: Test `DayOfWeek` TextChoices
- ✅ **Default Values**: Test default availability settings
- ✅ **Availability Methods**: Test `is_available_on_day()`, `is_available_at_time()`
- ✅ **ArrayField**: Test `available_days` ArrayField functionality
- ✅ **Helper Methods**: Test `get_available_days_of_week()`, `set_available_days()`

## 🔧 Test Setup and Fixtures

### setUp Method
```python
def setUp(self):
    """Set up test data."""
    self.user = User.objects.create_user(
        email='test@example.com',
        username='testuser',
        password='testpass123'
    )
    
    self.organization = Organization.objects.create(
        name='Test Organization',
        # ... other fields
    )
```

### Test Data Patterns
- Use consistent test data across tests
- Create minimal but complete test objects
- Use descriptive variable names
- Clean up test data in tearDown if necessary

## 📊 Test Coverage Requirements

### Minimum Coverage
- **Models**: 90% line coverage
- **Admin**: 80% line coverage
- **Views**: 85% line coverage
- **Utils**: 95% line coverage

### Critical Areas
- **Availability Logic**: 100% coverage for AvailabilityMixin methods
- **Business Logic**: 100% coverage for critical business rules
- **Data Validation**: 100% coverage for model validations
- **Security**: 100% coverage for authentication and authorization

## 🚀 Running Tests

### Run All Tests
```bash
uv run python backend/manage.py test
```

### Run Specific App Tests
```bash
uv run python backend/manage.py test apps.organizations
uv run python backend/manage.py test apps.services
uv run python backend/manage.py test apps.users
uv run python backend/manage.py test apps.bookings
```

### Run Specific Test File
```bash
uv run python backend/manage.py test apps.organizations.tests.test_models
uv run python backend/manage.py test apps.services.tests.test_availability
```

### Run with Coverage
```bash
uv run coverage run --source='.' manage.py test
uv run coverage report
uv run coverage html
```

## 📋 Test Checklist

### Before Committing
- [ ] All tests pass
- [ ] Test coverage meets requirements
- [ ] No test data pollution between tests
- [ ] Tests are properly organized in `tests/` folders
- [ ] Test files follow naming conventions
- [ ] setUp methods create clean test data
- [ ] Tests are independent and isolated

### Code Review
- [ ] Tests cover all new functionality
- [ ] Tests cover edge cases and error conditions
- [ ] Tests are readable and maintainable
- [ ] Test assertions are specific and meaningful
- [ ] No hardcoded test data that could become outdated

## 🎯 Best Practices

### DO ✅
- Use descriptive test names
- Test one thing per test method
- Use proper setUp and tearDown
- Test both success and failure cases
- Use factories for complex test data
- Keep tests simple and focused

### DON'T ❌
- Don't test Django built-in functionality
- Don't write tests that depend on each other
- Don't use hardcoded dates/times that might fail
- Don't ignore test coverage
- Don't write tests without assertions
- Don't use production data in tests

## 🔍 Example Test Structure

```python
class ServiceModelTests(TestCase):
    """Test cases for Service model."""
    
    def setUp(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='test@example.com',
            username='testuser',
            password='testpass123'
        )
        
        self.service = Service.objects.create(
            name='Test Service',
            # ... other fields
        )
    
    def test_service_creation(self):
        """Test service creation."""
        self.assertEqual(self.service.name, 'Test Service')
        # ... more assertions
    
    def test_service_str_representation(self):
        """Test string representation."""
        expected = f"{self.service.name} - {self.service.organization.name}"
        self.assertEqual(str(self.service), expected)
    
    def test_availability_methods(self):
        """Test availability checking methods."""
        # Test availability logic
        self.assertTrue(self.service.is_available_on_day(date.today()))
```

## 📚 Additional Resources

- [Django Testing Documentation](https://docs.djangoproject.com/en/stable/topics/testing/)
- [Django Test Best Practices](https://test-driven-django-development.readthedocs.io/en/latest/)
- [Python unittest Documentation](https://docs.python.org/3/library/unittest.html)

---

**Remember**: Good tests are the foundation of maintainable code. Invest time in writing comprehensive, clear, and reliable tests.
