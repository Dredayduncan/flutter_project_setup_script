# Flutter Project Setup Script

This script automates the process of setting up a new Flutter project with various configuration options. It uses the Very Good CLI to create a project structure and then customizes it based on user preferences.

## Features

1. Creates a new Flutter project using Very Good CLI
2. Offers choice between flutter_bloc and Riverpod for state management
3. Optional Firebase integration
4. Optional Firebase Cloud Messaging setup for push notifications
5. Removes default counter example and related imports
6. Sets up a basic project structure with services folder

## Prerequisites

Before running this script, ensure you have the following installed:

- Flutter SDK
- Dart SDK
- Firebase (`npm install -g firebase-tools`)
- Very Good CLI (`dart pub global activate very_good_cli`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

## Usage

1. Make the script executable:
   ```
   chmod +x setup_flutter_project.sh
   ```
2. Run the script:
   ```
   ./setup_flutter_project.sh
   ```
3. Follow the prompts to configure your project:
   - Enter your project name
   - Choose state management solution (flutter_bloc or Riverpod)
   - Decide whether to set up Firebase integration
   - Choose whether to set up Firebase Cloud Messaging for notifications

## What the Script Does

1. Creates a new Flutter project using Very Good CLI
2. Adds common dependencies (dio, flutter_local_notifications, get_it)
3. Sets up chosen state management solution
4. Integrates Firebase if chosen
5. Sets up Firebase Cloud Messaging if chosen
6. Creates a NotificationService if Firebase Cloud Messaging is selected
7. Updates the main App widget to initialize notifications
8. Removes the default counter example and related imports
9. Adds some development dependencies (flutter_test, mocktail)

## Notes

- This script is designed to work on Unix-like systems (macOS, Linux). Some modifications may be needed for Windows.
- The script uses `sed` for file modifications. The syntax may differ slightly between macOS and Linux.
- After running the script, you may need to manually adjust some code, especially for full Riverpod integration or Firebase configuration.
- Always review the generated code and make necessary adjustments for your specific project requirements.

## Troubleshooting

If you encounter any issues:
1. Ensure all prerequisites are correctly installed.
2. Check that you have the necessary permissions to create files and directories in the target location.
3. If using Linux, you may need to modify the `sed` commands in the script (remove the `''` after `-i`).

For any persistent issues, please check the script output for error messages and consult the Flutter and Firebase documentation as needed.