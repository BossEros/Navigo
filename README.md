# project_navigo

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

API Key Configuration
This project uses Google Maps APIs which require an API key. To set up the project:

1. Get your Google Maps API key from the Google Cloud Console
2. Create the configuration file:
    - Copycp lib/config/env_config.template.dart lib/config/env_config.dart

3. Edit lib/config/env_config.dart and replace YOUR_API_KEY_HERE with your actual API key
4. Make sure to add API key restrictions in the Google Cloud Console:
    - Set HTTP referrer restrictions
    - Add Android/iOS application restrictions
    - Enable only the specific APIs you need

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
