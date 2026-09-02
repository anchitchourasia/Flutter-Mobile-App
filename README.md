# HEG HRMS Mobile Application

A Flutter-based mobile application for internal HR operations, vehicle-pass workflows, permissions, employee lookups, document handling, approvals, and gate-log integration.

> **Status:** Active development — the dashboard and key workflow modules are available, while several HRMS modules continue to evolve.

## Overview

HEG HRMS Mobile Application brings multiple internal operational workflows into a unified Flutter client. The project focuses on a mobile-first experience for HR teams, security teams, approvers, employees, contractors, and gate operations.

The application is structured around reusable screens, models, service layers, API clients, and widgets. It supports both Android and iOS project targets and is designed to connect to environment-specific backend services without publishing any infrastructure details in source control.

## Highlights

- Mobile dashboard with role-oriented navigation.
- Vehicle Pass Registry with search, filtering, summary cards, pagination, and empty states.
- Pass entry, update, read-only review, and sticker-generation workflows.
- Employee and contractor lookup with type validation.
- Document metadata, attachment selection, download support, and compliance-oriented flows.
- Workflow actions for saving, submission, confirmation, approval, rejection, and modification.
- Pass history and status visibility.
- Permission-system and CVPS-oriented screens.
- Profile, notifications, insurance, leave, attendance, and employee-management foundations.

## Screens

### Mobile Dashboard

The home experience presents a clear navigation hub for HRMS functions. Available modules include profile, pass, and permission operations; planned modules are clearly represented as works in progress.

### Vehicle Pass Registry

The Vehicle Pass Registry is a read-only operational view for finding and reviewing pass records. It supports searching by pass, vehicle, employee, or contractor details and filtering by status, employee type, and vehicle type. The screen includes page-size controls, pagination, visual status indicators, and a dedicated no-results state rather than failing when a filter produces no matching records.

### Pass Entry and Review

The pass flow captures vehicle, employee or contractor, gate, parking, pass, and document details. It supports save and submit actions, view mode, approval-oriented actions, and historical status visibility.

### Supporting HRMS Modules

The project includes screens and foundations for login, profile, applicants, employee details, insurance upload and review, notifications, leave, attendance, manpower, overtime, settings, self-service, CVPS, and approver-related workflows.

## Architecture

```text
Flutter Client
├── Core configuration and application bootstrap
├── Data/API clients
├── Domain models
├── Feature screens and workflows
├── Reusable UI widgets
└── Platform targets: Android, iOS, Web, Windows, macOS, Linux
```

The source tree includes dedicated `core`, `data`, `models`, `screens`, `services`, and `widgets` layers. The public repository intentionally excludes private backend environments and local runtime values.

## Technology

| Area | Tools and libraries |
| --- | --- |
| Client framework | Flutter and Dart |
| Networking | `http` |
| Local storage | `shared_preferences`, `sqflite`, `hive`, `hive_flutter` |
| Documents | `file_picker`, `open_filex`, `share_plus` |
| PDF workflows | `pdf`, `printing` |
| Connectivity and messaging | `connectivity_plus`, `stomp_dart_client` |
| Runtime configuration | `flutter_dotenv` |
| Static analysis | `flutter_lints` |
| Delivery pipeline | Jenkins-based CI/CD |

## Repository Layout

```text
HEG/
├── android/                 # Android platform target
├── ios/                     # iOS platform target
├── web/                     # Web platform target
├── windows/                 # Windows platform target
├── macos/                   # macOS platform target
├── linux/                   # Linux platform target
├── assets/                  # Bundled visual assets
├── lib/
│   ├── core/                # Bootstrap and configuration abstractions
│   ├── data/                # API and data-access clients
│   ├── models/              # Data models
│   ├── screens/             # HRMS feature pages
│   ├── services/            # Application services
│   └── widgets/             # Shared user-interface components
└── pubspec.yaml             # Dependencies and app metadata
```

## Getting Started

### Prerequisites

- Flutter SDK compatible with the SDK constraint in `HEG/pubspec.yaml`.
- Android Studio or Visual Studio Code with the Flutter and Dart extensions.
- An Android emulator or physical Android device for Android testing.
- macOS with Xcode for iOS builds and real-iPhone testing.

### Install

```bash
cd HEG
flutter pub get
flutter run
```

### Configuration

The repository is designed to use local or environment-provided configuration. Do not commit production URLs, internal IP addresses, API keys, access tokens, passwords, database strings, or environment files.

Create local configuration from approved project templates and keep actual values outside version control. Review `.gitignore` before committing configuration changes.

### Android Device Development

For local backend testing with a USB-connected Android device, create an ADB reverse tunnel using the port used by your local service:

```bash
adb reverse tcp:<PORT> tcp:<PORT>
```

This technique is for local development only. A release build should use an approved, stable, secured environment endpoint.

### Build

```bash
cd HEG
flutter build apk --release
```

## Project Status

| Area | Status |
| --- | --- |
| Dashboard shell and navigation | In progress |
| Authentication and session flow | In progress |
| Vehicle Pass Registry | Implemented and evolving |
| Pass entry and review workflow | Implemented and evolving |
| Approval and history workflow | Implemented and evolving |
| Permission and CVPS capabilities | In progress |
| Attendance, settings, and employee modules | Planned / in progress |
| Production configuration and release hardening | In progress |

## Security Notes

This public repository is intended to demonstrate the application architecture and mobile implementation. It must contain only sanitized code and sample data.

Before publishing changes, confirm that no real credentials or internal infrastructure details are present. If a credential was ever committed, rotate it immediately; removing it only from the newest version does not remove it from previous Git history.

## Roadmap

- Complete remaining dashboard modules.
- Expand role-based workflow handling.
- Improve offline and connectivity behavior.
- Add broader operational reporting and analytics.
- Strengthen release configuration and automated quality checks.
- Continue accessibility, validation, and mobile UX improvements.

## Screenshots

Screenshots are intentionally not embedded yet because public images must be sanitized before upload. Replace all employee names, employee codes, vehicle numbers, pass numbers, contractor information, and other internal operational data with demo values before adding screenshots under `docs/screenshots/`.

Suggested image paths after sanitization:

```text
docs/screenshots/dashboard.png
docs/screenshots/pass-registry.png
```

Then embed them as follows:

```md
![Dashboard](docs/screenshots/dashboard.png)
![Vehicle Pass Registry](docs/screenshots/pass-registry.png)
```

## CI/CD

The repository includes a Jenkins-oriented delivery pipeline. For production usage, environment-specific values should be injected through the organization’s approved secure build and deployment process rather than stored in the repository.

## License

No open-source license is currently declared. Reuse, redistribution, and publication remain subject to the applicable owner and organization policies.

## Author

Built as a Flutter mobile application for HRMS, vehicle-pass management, permissions, and related operational workflows.
