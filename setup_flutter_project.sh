#!/bin/bash

# ---------------------  FUNCTIONS -----------------------
# Function to check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

setup_auto_route() {

	# create the routes file in the routes folder
	echo "Setting up auto_route..."
	mkdir -p lib/routes
	touch lib/routes/routes.dart

	# Update the content of the routes.dart file
	cat <<EOT >lib/routes/routes.dart
	import 'package:auto_route/annotations.dart';
	import 'package:auto_route/auto_route.dart';
	import 'package:$1/home/home_screen.dart';
	part 'routes.gr.dart';

	@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
	class AppRouter extends RootStackRouter {
		AppRouter();

		@override
		List<AutoRoute> get routes {
			return [
				AutoRoute(page: HomeRoute.page, path: '/home', initial: true),
			];
		}
	}

EOT

	echo "Running build runner..."
	dart run build_runner build --delete-conflicting-outputs
	flutter pub get

}

default_setup() {
	# delete the lib/counter folder
	rm -r lib/counter

	# delete the test/counter folder
	rm -r test/counter

	# Create a home_screen in a home folder
	mkdir -p lib/home
	touch lib/home/home_screen.dart

	# add the content of the home page
	cat <<EOT >>lib/home/home_screen.dart
	import 'package:auto_route/auto_route.dart';
	import 'package:flutter/material.dart';
	import 'package:$1/l10n/l10n.dart';

	@RoutePage()
	class HomeScreen extends StatelessWidget {
		const HomeScreen({super.key});

		@override
		Widget build(BuildContext context) {
			return Center(
			child: Text(context.l10n.counterAppBarTitle),
			);
		}
	}


EOT

	# Setup the auto_route
	setup_auto_route $1

	# Update the app.dart file
	echo "Updating lib/app/view/app.dart..."
	# delete the current app.dart
	rm lib/app/view/app.dart
	# create a new app.dart
	touch lib/app/view/app.dart
	# update the new app.dart
	cat <<EOT >>lib/app/view/app.dart
	import 'package:auto_route/auto_route.dart';
	import 'package:$1/l10n/l10n.dart';
	import 'package:flutter/material.dart';
	import 'package:$1/setup/setup.dart';
	import 'package:$1/routes/routes.dart';

	class App extends StatefulWidget {
		const App({super.key});

		@override
		State<App> createState() => _AppState();
	}

	class _AppState extends State<App> {
		late RouterConfig<UrlState> appRouterConfig;

		@override
		void initState() {
			super.initState();

			// Auto Router config
			final appRouter = getIt.get<AppRouter>();
			appRouterConfig = appRouter.config();
		}

		@override
		Widget build(BuildContext context) {
			return MaterialApp.router(
				theme: ThemeData(
					appBarTheme: AppBarTheme(
						backgroundColor: Theme.of(context).colorScheme.inversePrimary,
					),
					useMaterial3: true,
				),
				localizationsDelegates: AppLocalizations.localizationsDelegates,
				supportedLocales: AppLocalizations.supportedLocales,
				routerConfig: appRouterConfig,
			);
		}
	}

EOT
	echo "Updated App and App Test files"

	# replace the import and expect line in the test/app/view/app_test.dart file
	sed -i '' "s/import 'package:$1\/counter\/counter.dart';/import 'package:$1\/home\/home_screen.dart';/" test/app/view/app_test.dart
	sed -i '' 's/CounterPage/HomeScreen/' test/app/view/app_test.dart

	# Remove all instances of the counter import
	find . -name "*.dart" -type f -print0 | xargs -0 sed -i '' "s/import 'package:$1\/counter\/counter.dart';//g"
	echo "Removed all instances of 'import 'package:$1/counter/counter.dart';' from Dart files"

}

create_setup_files() {
	# Create the api essentials
	mkdir -p lib/api_utils

	# TODO: Change path
	cp -r ../flutter_project_setup_test/api_utils lib

	# Create the file with the getIt and Dio setup
	echo "Creating setup files"
	mkdir -p lib/setup
	touch lib/setup/setup.dart

	# add the content of the setup including the Dio
	cat <<EOT >>lib/setup/setup.dart
	import 'package:dio/dio.dart';
	import 'package:get_it/get_it.dart';
	import 'package:$1/routes/routes.dart';

EOT

	# Conditionally add the Interceptor imports
	if [ "$2" = "y" ]; then
		cat <<EOT >>lib/setup/setup.dart

		import 'package:flutter_secure_storage/flutter_secure_storage.dart';
		import 'package:$1/api_utils/interceptors/custom_dio_interceptor.dart';
		import 'package:$1/services/auth_service.dart';
		import 'package:$1/services/platform_services/storage_services/token_storage_service.dart';
EOT
	fi

	cat <<EOT >>lib/setup/setup.dart
	final getIt = GetIt.instance;

	final dio = Dio(
		BaseOptions(
			baseUrl: '',
			connectTimeout: const Duration(seconds: 30),
		),
	);

	Future<void> registerDependencies() async {
		getIt
			..registerSingleton<Dio>(dio)
			..registerSingleton<AppRouter>(AppRouter());

EOT

	# Conditionally add the RefreshInterceptor if the user is working with JWT
	if [ "$2" = "y" ]; then

		# Add the models folder which contains the TokenModel
		cp -r ../flutter_project_setup_test/models lib
		mkdir -p lib/services
		cp -r ../flutter_project_setup_test/services/auth_service.dart lib/services
		cp -r ../flutter_project_setup_test/services/platform_services lib/services
		echo "Successfully added Auth Service and TokenModel"

		cat <<EOT >>lib/setup/setup.dart

		// Setup secure storage
		AndroidOptions getAndroidOptions() => const AndroidOptions(
				encryptedSharedPreferences: true,
			);

		final secureStorage = FlutterSecureStorage(
			aOptions: getAndroidOptions(),
		);

		getIt..registerSingleton<AuthService>(AuthService())
			..registerSingleton<TokenStorageService>(
				TokenStorageService(
					secureStorage,
					getIt.get<AuthService>(),
				)
			);

		// Safely assign it to the refresh token interceptor
		getIt.get<Dio>().interceptors.add(
			CustomDioInterceptor(
			tokenStorageService: getIt.get<TokenStorageService>(),
			dio: getIt.get<Dio>(),
			onRefreshTokenExpired: () {},
			),
		);
EOT
	fi
	cat <<EOT >>lib/setup/setup.dart
			}
EOT

	# Configure Auto Route and other default configs
	default_setup $1
}

# Function to Add Riverpod to the project
add_riverpod() {
	echo "Adding Riverpod..."
	flutter pub add flutter_riverpod

	# remove the bloc and flutter_bloc packages
	echo 'Removing bloc dependencies'
	flutter pub remove flutter_bloc
	flutter pub remove bloc
	flutter pub remove bloc_test

	# delete the current bootstrap file
	rm lib/bootstrap.dart

	# create a new bootstrap file
	touch lib/bootstrap.dart
	cat <<EOT >>lib/bootstrap.dart
		import 'dart:async';
		import 'dart:developer';
		import 'package:$1/app/app.dart';
		import 'package:flutter_riverpod/flutter_riverpod.dart';
		import 'package:$1/setup/setup.dart';
		import 'package:flutter/widgets.dart';

		Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
			FlutterError.onError = (details) {
				log(details.exceptionAsString(), stackTrace: details.stack);
			};
			// Add cross-flavor configuration here

			// register the rest of the dependencies
			await registerDependencies();

			await getIt.allReady();

			runApp(
				ProviderScope(
				child: await builder(),
				),
			);
		}

EOT
}

setup_firebase_project() {
	# Get the project_id
	local project_id = $3

	# check a firebase project ID was not provided and create a new project
	if ! [ -z "$project_id" ]; then

		# check if firebase is installed
		if ! command_exists firebase; then
			echo "firebase is not installed. Please install it first."
			exit 1
		fi

		# create the firebase project
		echo "Creating $1 development flavor firebase project..."

		# Convert underscores to hyphens and store in a new variable
		local display_name="$1"
		local project_name_with_hyphens="${display_name//_/-}"
		project_id=$project_name_with_hyphens-flavors-dev

		# Run the Firebase command and capture stderr to a variable
		local error_message=$(firebase projects:create --display-name="$project_name_with_hyphens" "$project_id" 2>&1)

		# Capture the exit status
		local exit_status=$?

		# Check the exit status and print error message if there was a failure
		if [ $exit_status -ne 0 ]; then
			echo "Failed to create Firebase project. Exiting..."
			echo "Error Details: $error_message"
			exit 1
		else
			echo "Firebase project created successfully"
		fi

	fi

	# Check if FlutterFire CLI is installed
	if ! command_exists flutterfire; then
		echo "FlutterFire CLI is not installed. Installing now..."
		dart pub global activate flutterfire_cli
	fi

	# Check if the user provided a project ID
	if ! [ -z "$3" ]; then

		# if the user does not have a project with that ID
		if ! [ firebase projects:list | grep -q "$project_id" ]; then
			echo "Project ID $project_id does not exist. Please create it first."
			exit 1
		fi

	else

		# Continuously check for the created firebase project
		local max_retries=10 # Set a maximum number of retries to avoid infinite loops
		local attempt=1

		while ! firebase projects:list | grep -q "$project_id"; do
			echo "Project with ID '$project_id' not found. Attempt $attempt/$max_retries..."

			# Increment attempt counter
			((attempt++))

			# Exit if maximum retries reached
			if [ $attempt -gt $max_retries ]; then
				echo "Unable to integrate firebase. Max retries reached. Exiting..."
				exit 1
			fi

			# Wait before retrying
			sleep 1
		done

	fi

	echo "Setting up Firebase integration..."
	flutterfire config \
		--project=$project_id \
		--out=lib/firebase_config/firebase_options_dev.dart \
		--ios-bundle-id=$2.dev \
		--macos-bundle-id=$2.dev \
		--android-package-name=$2.dev \
		--web-app-id=$2-dev \
		--windows-app-id=$2.dev \
		--platforms=android,ios,macos,web,linux,windows

	echo "Adding firebase_core..."
	flutter pub add firebase_core
}

setup_notifications() {
	echo "Adding firebase_messaging..."
	flutter pub add firebase_messaging

	echo "Adding flutter_local_notifications..."
	flutter pub add flutter_local_notifications

	# Update the AppDelegate.swift file with the notification integration
	echo "Updating AppDelegate.swift with notification configurations..."
	FILE_PATH="ios/Runner/AppDelegate.swift"

	# The line we want to add
	NEW_LINE="        if #available(iOS 10.0, *) {\n          UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n        }"

	# The line before which we want to add our new line
	TARGET_LINE="GeneratedPluginRegistrant.register(with: self)"

	# Create a temporary file
	temp_file=$(mktemp)

	# Flag to check if we've added our new line
	added=false

	# Read the file line by line
	while IFS= read -r line; do
		# If we find the target line and haven't added our new line yet
		if [[ $line == *"$TARGET_LINE"* ]] && [ "$added" = false ]; then
			# Add our new line
			echo -e "$NEW_LINE" >>"$temp_file"
			# Set the flag to true
			added=true
		fi
		# Write the current line to the temp file
		echo "$line" >>"$temp_file"
	done <"$FILE_PATH"

	# If we didn't find the target line, print an error message
	if [ "$added" = false ]; then
		echo "Error: Couldn't find the line 'GeneratedPluginRegistrant.register(with: self)' in $FILE_PATH"
		rm "$temp_file"
		exit 1
	fi

	# Replace the original file with the modified one
	mv "$temp_file" "$FILE_PATH"

	echo "Successfully updated $FILE_PATH"

	# update the android/app/build.gradle with the notification integration
	echo "Updating build.gradle with notification configurations..."

	# Create a temporary file to store the modified content
	local temp_build_gradle_file=$(mktemp)

	# Flag to track if we're currently inside the dependencies block
	local in_dependencies_block=false

	# Read the original file line by line
	while IFS= read -r line; do
		if [[ $line == *"dependencies {"* ]]; then
			# We've found the dependencies block
			in_dependencies_block=true

			# Write the opening of the dependencies block
			echo "$line" >>"$temp_build_gradle_file"

			# Add our new dependencies
			echo "    // Desugar library for using Java 8+ APIs on Android 7 and below" >>"$temp_build_gradle_file"
			echo "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:1.2.2'" >>"$temp_build_gradle_file"
			echo "    // Window Manager library for foldable device support" >>"$temp_build_gradle_file"
			echo "    implementation 'androidx.window:window:1.0.0'" >>"$temp_build_gradle_file"
			echo "    implementation 'androidx.window:window-java:1.0.0'" >>"$temp_build_gradle_file"
			echo "" >>"$temp_build_gradle_file"

		elif [[ $line == "}" && $in_dependencies_block == true ]]; then
			# We've reached the end of the dependencies block
			in_dependencies_block=false
			echo "$line" >>"$temp_build_gradle_file"
		else
			# Write any other line as is
			echo "$line" >>"$temp_build_gradle_file"
		fi
	done <android/app/build.gradle

	# Replace the original file with our modified version
	mv "$temp_build_gradle_file" android/app/build.gradle

	echo "build.gradle has been updated successfully"

	# Update teh AndroidManifest.xml file with the notification integration
	echo "Updating the AndroidManifest.xml with notification configurations..."

	# Create a temporary file
	local tmp_file=$(mktemp)

	# Start writing to the temporary file
	cat <<EOF >"$tmp_file"
	<manifest xmlns:android="http://schemas.android.com/apk/res/android"
		package="$3">

		<uses-permission android:name="android.permission.INTERNET" />
		<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
		<uses-permission android:name="android.permission.VIBRATE" />
		<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
		<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
		<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
		<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

		<application
			android:label="\${appName}"
			android:name="\${applicationName}"
			android:icon="@mipmap/ic_launcher">
			
			<meta-data
				android:name="com.google.firebase.messaging.default_notification_channel_id"
				android:value="max_importance_channel" />

			<meta-data
				android:name="com.google.firebase.messaging.default_notification_icon"
				android:resource="@drawable/ic_launch_image" />

			<activity
				android:name=".MainActivity"
				android:exported="true"
				android:launchMode="singleTask"
				android:theme="@style/LaunchTheme"
				android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
				android:hardwareAccelerated="true"
				android:windowSoftInputMode="adjustResize"
				android:showWhenLocked="true"
				android:turnScreenOn="true">
				<meta-data
					android:name="io.flutter.embedding.android.NormalTheme"
					android:resource="@style/NormalTheme" />
				<meta-data
					android:name="flutter_deeplinking_enabled"
					android:value="true" />

				<intent-filter>
					<action android:name="android.intent.action.MAIN" />
					<category android:name="android.intent.category.LAUNCHER" />
				</intent-filter>

				<intent-filter android:autoVerify="true">
					<action android:name="android.intent.action.VIEW" />

					<category android:name="android.intent.category.DEFAULT" />
					<category android:name="android.intent.category.BROWSABLE" />

					<!--TODO: REPLACE WITH YOUR DEEP LINK-->
					<data android:scheme="app" />
					<data android:host="thedomain.com" />
				</intent-filter>
			</activity>
			<meta-data
				android:name="flutterEmbedding"
				android:value="2" />
			<service
				android:name="com.dexterous.flutterlocalnotifications.ForegroundService"
				android:exported="false"
				android:stopWithTask="false" />

			<receiver
				android:exported="false"
				android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
			<receiver
				android:exported="false"
				android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
			<receiver
				android:exported="false"
				android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
				<intent-filter>
					<action android:name="android.intent.action.BOOT_COMPLETED" />
					<action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
					<action android:name="android.intent.action.QUICKBOOT_POWERON" />
					<action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
				</intent-filter>
			</receiver>
		</application>
	</manifest>
EOF

	# Replace the original file with the new content
	mv "$tmp_file" android/app/src/main/AndroidManifest.xml

	echo "AndroidManifest.xml has been updated successfully."

	echo "Creating notification service"
	mkdir -p lib/services
	cp -r ../flutter_project_setup_test/services/notification_service lib/services

	# Update the bootstrap.dart
	echo "Updating bootstrap.dart..."
	# remove the current bootstrap file
	rm lib/bootstrap.dart
	# create a new bootstrap file
	touch lib/bootstrap.dart

	local state_choice="$2"

	# Update the bootstrap file with the notifications setup
	cat <<EOT >>lib/bootstrap.dart

	import 'dart:async';
	import 'dart:developer';

	import 'package:$1/app/app.dart';
	import 'package:$1/services/notification_service/notification_service.dart';
	import 'package:$1/setup/setup.dart';
	import 'package:flutter/widgets.dart';
EOT

	# Conditionally add Riverpod import and ProviderScope based on state_choice
	if [ "$state_choice" = "2" ]; then
		cat <<EOT >>lib/bootstrap.dart
	import 'package:flutter_riverpod/flutter_riverpod.dart';
EOT
	fi

	cat <<EOT >>lib/bootstrap.dart

	Future<void> bootstrap({
		required NotificationService notificationService,
	}) async {
		FlutterError.onError = (details) {
			log(details.exceptionAsString(), stackTrace: details.stack);
		};
		// Add cross-flavor configuration here

		// register the notification service
		getIt.registerSingleton<NotificationService>(notificationService);

		// register the rest of the dependencies
		await registerDependencies();

		await getIt.allReady();

		runApp(
EOT

	# Conditionally add ProviderScope based on state_choice
	if [ "$state_choice" = "2" ]; then
		cat <<EOT >>lib/bootstrap.dart
			ProviderScope(
				child: App(),
			),
EOT
	else
		cat <<EOT >>lib/bootstrap.dart
			App(),
EOT
	fi

	cat <<EOT >>lib/bootstrap.dart
		);
	}
EOT

	# Update the main_development.dart
	echo "Updating lib/main_development.dart with notification setup..."

	# remove the main_development.dart file
	rm lib/main_development.dart

	# create a new one
	touch lib/main_development.dart

	# update the file
	cat <<EOT >>lib/main_development.dart
	import 'dart:async';
	import 'package:$1/bootstrap.dart';
	import 'package:$1/firebase_config/firebase_options_dev.dart';
	import 'package:$1/services/notification_service/notification_service.dart';
	import 'package:firebase_core/firebase_core.dart';
	import 'package:firebase_messaging/firebase_messaging.dart';
	import 'package:flutter/material.dart';

	NotificationService notificationService = NotificationService();

	@pragma('vm:entry-point')
	Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
		await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
		await notificationService.setupLocalNotifications();
		notificationService.handleForegroundMessage(message);
		// Note: This function runs in a separate isolate and cannot
		// directly update the UI
		// or trigger navigation. It's primarily used for data processing
		// or local notifications.
	}

	void main() async {
		WidgetsFlutterBinding.ensureInitialized();
		await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

		// Set the background messaging handler early on, as a named top-level function
		FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

		await bootstrap(
			notificationService: notificationService,
		);
	}
EOT

	echo "Updating lib/main_staging.dart with notification setup..."
	# remove the main_staging.dart file
	rm lib/main_staging.dart

	# create a new one
	touch lib/main_staging.dart

	# update the file
	cat <<EOT >>lib/main_staging.dart
	import 'package:$1/bootstrap.dart';
	import 'package:$1/services/notification_service/notification_service.dart';
	import 'package:flutter/material.dart';

	final notificationService = NotificationService();

	void main() async {
		WidgetsFlutterBinding.ensureInitialized();
		// await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

		await bootstrap(notificationService: notificationService);
	}
EOT

	echo "Updating lib/main_production.dart with notification setup..."
	# remove the main_production.dart file
	rm lib/main_production.dart

	# create a new one
	touch lib/main_production.dart

	# update the file
	cat <<EOT >>lib/main_production.dart
	import 'package:$1/bootstrap.dart';
	import 'package:$1/services/notification_service/notification_service.dart';
	import 'package:flutter/material.dart';

	final notificationService = NotificationService();

	void main() async {
		WidgetsFlutterBinding.ensureInitialized();
		// await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

		await bootstrap(notificationService: notificationService);
	}
EOT

	echo "Updating lib/app/view/app.dart with notification setup..."

	local APP_FILE_PATH="lib/app/view/app.dart"

	# The imports to add
	local import_1="import 'package:$1/services/notification_service/notification_service.dart';"
	local import_2="import 'package:firebase_messaging/firebase_messaging.dart';"

	sed -i '' "1s|^|$import_1\n|" "$APP_FILE_PATH"
	sed -i '' "1s|^|$import_2\n|" "$APP_FILE_PATH"

	# The block of code to insert
	local notif_setup='
		WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
		final notificationService = getIt.get<NotificationService>();

		await notificationService.setupLocalNotifications();

		// handle notifications opened in the foreground
		FirebaseMessaging.onMessage.listen(
			notificationService.handleForegroundMessage,
		);

		// Handle notifications opened when the app is in the background
		FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
			notificationService.processNotification(
			messageData: message.data,
			);
		});

		// Process any notifications that opened the app when it was terminated
		await notificationService.processNotification();
		});
	'

	# Find the start and end line numbers of the initState function
	start_line=$(grep -n -m 1 'void initState() {' "$APP_FILE_PATH" | cut -d : -f 1)
	end_line=$(awk "NR>$start_line" "$APP_FILE_PATH" | grep -n -m 1 '^\s*}' | cut -d : -f 1)
	end_line=$((start_line + end_line))

	# Insert the block of code just before the closing brace of initState
	#  Extracts everything before the closing brace within initState
	head -n $((end_line - 1)) "$APP_FILE_PATH" >temp_file
	echo "$notif_setup" >>temp_file
	# Appends the remaining content after the closing brace.
	tail -n +$((end_line)) "$APP_FILE_PATH" >>temp_file

	# Replace the original file with the modified content
	mv temp_file "$APP_FILE_PATH"

	echo "Successfully updated $APP_FILE_PATH"

}

# Function to remove flutter_gen from pubspec.yaml
remove_flutter_gen() {
	if grep -q "flutter_gen: any" pubspec.yaml; then
		sed -i '' '/flutter_gen: any/d' pubspec.yaml
		echo "Removed 'flutter_gen: any' from pubspec.yaml"
	else
		echo "flutter_gen: any not found in pubspec.yaml"
	fi
}

# ------------------- MAIN SCRIPT --------------------

# Check if Flutter is installed
if ! command_exists flutter; then
	echo "Flutter is not installed. Please install Flutter and try again."
	exit 1
fi

# Check if Very Good CLI is installed
if ! command_exists very_good; then
	echo "Very Good CLI is not installed. Installing now..."
	dart pub global activate very_good_cli
fi

# Prompt for project name with validation
while true; do
	read -p "Enter your project name (lowercase letters and underscores only): " project_name
	if [[ "$project_name" =~ ^[a-z_]+$ ]]; then
		break
	else
		echo "Invalid project name. Please use only lowercase letters and underscores."
	fi
done

read -p "Enter your app name (hit the 'Enter' key to use project name): " app_name

# Prompt for application_id with validation
while true; do
	read -p "Enter your application-id (eg. com.example.app):" application_id

	# check if it's not empty and exit the loop
	if ! [ -z "$application_id" ]; then
		break
	else
		echo "Invalid application_id. Please use this format: com.example.app."
	fi
done

# Prompt for state management choice
while true; do
	read -p "Choose state management (1 for flutter_bloc, 2 for Riverpod): " state_choice
	case $state_choice in
	1 | 2) break ;;
	*) echo "Please enter 1 or 2." ;;
	esac
done

# Prompt for API Interceptor for JWT integration
while true; do
	read -p "Are you working with JWT and an external backend? (y/n) " jwt_choice
	case $jwt_choice in
	y | n) break ;;
	*) echo "Please enter y or n." ;;
	esac
done

# Prompt for setting up dynamic links
while true; do
	read -p "Do you want to setup dynamic links? (y/n) " dynamic_link_choice
	case $dynamic_link_choice in
	y | n) break ;;
	*) echo "Please enter y or n." ;;
	esac
done

# Prompt for Firebase integration
while true; do
	read -p "Do you want to set up Firebase integration? (y/n) " firebase_choice
	case $firebase_choice in
	y | n) break ;;
	*) echo "Please enter y or n." ;;
	esac
done

if [ "$firebase_choice" = "y" ]; then

	# Prompt for retrieving the firebase project ID
	read -p "Enter your firebase project ID (leave empty to create one)" firebase_project_id

	# Prompt for Firebase Messaging notifications
	while true; do
		read -p "Do you want to set up Firebase Messaging notifications? (y/n) " messaging_choice
		case $messaging_choice in
		y | n) break ;;
		*) echo "Please enter y or n." ;;
		esac
	done
fi

# Create Flutter project using Very Good CLI
very_good create flutter_app $project_name --application-id $application_id

if [ $? -ne 0 ]; then
	echo "Failed to create Flutter project. Exiting..."
	exit 1
fi

# Navigate to the project directory
echo "Navigating to project directory"
cd $project_name || {
	echo "Failed to change to project directory. Exiting..."
	exit 1
}

# # Check if the app name provided is not empty and set the app name
# if ! [ -z "$app_name" ]; then
# 	# Install the rename dependency globally if it doesn't exist
# 	if ! dart pub global list | grep -q 'rename'; then
# 		echo "Rename is not installed. Installing now..."
# 		dart pub global activate rename
# 	fi

# 	# Get the path where Dart pub global executables are installed
# 	pub_global_bin=$(dart pub global list | grep 'rename' | awk '{print $2}' | sed 's/bin\/rename//')
# 	pub_global_bin_path=$(dart pub global list | grep 'rename' | awk '{print $2}')

# 	echo "rename path" $pub_global_bin
# 	echo "full rename path" $pub_global_bin_path

# 	# Construct the full path to the rename executable
# 	dart_rename_executable="${pub_global_bin}/bin/rename"

# 	# Check if the rename executable exists
# 	if [ ! -f "$dart_rename_executable" ]; then
# 		echo "Rename executable not found at $dart_rename_executable."
# 		exit 1
# 	fi

# 	# rename the app to the given name
# 	echo "Setting app name..."
# 	"$dart_rename_executable" setAppName --targets ios,android,macos,web,linux,windows --value $app_name

# fi

# exit 1;

# Add common dependencies
echo 'Adding Dio...'
flutter pub add dio

echo 'Adding Get_it...'
flutter pub add get_it

echo 'Adding Equatable...'
flutter pub add equatable

echo 'Adding auto_route...'
flutter pub add auto_route

echo 'Removing flutter_gen added by dart fix --apply during the very_good setup...'
flutter pub remove flutter_gen

if [ "$jwt_choice" = "y" ]; then
	echo 'Adding flutter_secure_storage...'
	flutter pub add flutter_secure_storage
fi

# Add dev dependencies
echo 'Adding build_runner...'
flutter pub add --dev build_runner

echo 'Adding auto_route_generator...'
flutter pub add --dev auto_route_generator

# Create setup files
create_setup_files $project_name $jwt_choice

# Add state management dependency based on choice
if [ "$state_choice" = "1" ]; then
	echo "Adding flutter_bloc..."
elif [ "$state_choice" = "2" ]; then
	add_riverpod $project_name
fi

# Set up Firebase integration if chosen
if [ "$firebase_choice" = "y" ]; then
	setup_firebase_project $project_name $application_id $firebase_project_id
fi

# Set up Firebase Messaging notifications if chosen
if [ "$messaging_choice" = "y" ]; then
	echo "Setting up Firebase Messaging notifications..."
	setup_notifications $project_name $state_choice $application_id
fi

# echo 'Running "dart fix --apply" in' $project_name
dart fix --apply

# Remove 'flutter_gen: any' from pubspec.yaml
echo "Checking if flutter_gen was added..."
if grep -q "flutter_gen: any" pubspec.yaml; then
	echo "flutter_gen was added. Removing it..."
	remove_flutter_gen
else
	echo "flutter_gen was not added."
fi

echo "Project setup complete!"
echo "To run your project, navigate to the project directory and use 'flutter run'"

if [ "$state_choice" = "2" ]; then
	echo "Note: Basic Riverpod setup has been done, but you may need to manually adjust some code for full Riverpod integration."
fi

if [ "$jwt_choice" = "y" ]; then
	echo "Note: API, Auth, and TokenStorage services as well as the API Interceptor have been configured, and you will have to implement the refreshToken function in the AuthService."
fi

if [ "$firebase_choice" = "y" ]; then
	echo "Note: Firebase integration has been set up, but you may need to manually configure the Firebase project and update the configuration files."
fi

if [ "$messaging_choice" = "y" ]; then
	echo "Note: Firebase Messaging notifications have been set up, but you may need to implement the processNotification method in the NotificationService."
fi

if [ "$dynamic_link_choice" = "y" ]; then
	echo "Note: Dynamic Links have been set up, navigate to your AndroidManifest.xml and Info.plist to update the links, and to the appRouterConfig variable in the app.dart to configure them."
fi
