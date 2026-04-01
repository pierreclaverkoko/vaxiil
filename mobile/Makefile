.PHONY: clean get build test analyze format lint run-android run-ios run-web

# Clean build artifacts
clean:
	flutter clean
	flutter pub get

# Get dependencies
get:
	flutter pub get

# Generate code (for models, DI, etc.)
generate:
	flutter packages pub run build_runner build --delete-conflicting-outputs

# Watch for changes and generate code
watch:
	flutter packages pub run build_runner watch --delete-conflicting-outputs

# Run tests
test:
	flutter test --coverage

# Run tests with coverage
test-coverage:
	flutter test --coverage && genhtml coverage/lcov.info -o coverage/html

# Analyze code
analyze:
	flutter analyze

# Format code
format:
	flutter format .

# Lint code
lint: analyze

# Build for different platforms
build-android:
	flutter build apk --release

build-android-bundle:
	flutter build appbundle --release

build-ios:
	flutter build ios --release

build-web:
	flutter build web --release

# Run on different platforms
run-android:
	flutter run -d android

run-ios:
	flutter run -d ios

run-web:
	flutter run -d web

run-chrome:
	flutter run -d chrome

# Development helpers
dev-setup:
	flutter pub get
	flutter packages pub run build_runner build --delete-conflicting-outputs

dev-run:
	flutter run --debug

dev-profile:
	flutter run --profile

dev-release:
	flutter run --release

# Quality checks
quality: format analyze test

# Pre-commit hook setup
setup-hooks:
	chmod +x scripts/pre-commit.sh
	git config core.hooksPath .git/hooks
	ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit

# Update dependencies
upgrade:
	flutter pub upgrade
	flutter pub outdated

# Security audit
audit:
	flutter pub deps --style=tree

# Performance profiling
profile-android:
	flutter build apk --profile
	flutter run --profile -d android

profile-ios:
	flutter build ios --profile
	flutter run --profile -d ios

# Integration tests
integration-test:
	flutter test integration_test/

# Screenshot tests
screenshot-test:
	flutter test --update-goldens

# Documentation
docs:
	flutter pub global activate dartdoc
	flutter pub global run dartdoc

# Help
help:
	@echo "Available commands:"
	@echo "  clean          - Clean build artifacts"
	@echo "  get            - Get dependencies"
	@echo "  generate       - Generate code"
	@echo "  watch          - Watch for changes and generate code"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage"
	@echo "  analyze        - Analyze code"
	@echo "  format         - Format code"
	@echo "  lint           - Lint code"
	@echo "  build-android  - Build Android APK"
	@echo "  build-android-bundle - Build Android App Bundle"
	@echo "  build-ios      - Build iOS app"
	@echo "  build-web      - Build web app"
	@echo "  run-android    - Run on Android device"
	@echo "  run-ios        - Run on iOS device"
	@echo "  run-web        - Run on web"
	@echo "  run-chrome     - Run on Chrome"
	@echo "  dev-setup      - Development setup"
	@echo "  dev-run        - Run in debug mode"
	@echo "  dev-profile    - Run in profile mode"
	@echo "  dev-release    - Run in release mode"
	@echo "  quality        - Run all quality checks"
	@echo "  setup-hooks    - Setup pre-commit hooks"
	@echo "  upgrade        - Update dependencies"
	@echo "  audit          - Security audit"
	@echo "  profile-android - Profile Android app"
	@echo "  profile-ios    - Profile iOS app"
	@echo "  integration-test - Run integration tests"
	@echo "  screenshot-test - Run screenshot tests"
	@echo "  docs           - Generate documentation"
	@echo "  help           - Show this help message"
