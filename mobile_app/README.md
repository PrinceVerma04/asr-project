# ASR Mobile App

Simple Flutter client for the ASR backend running on your college server.

## Current Features

- set backend URL
- choose an audio file from the phone
- send audio to `/transcribe`
- show transcript response
- show saved output path returned by the server

## Backend URL

Use your reachable server URL, for example:

`http://192.168.162.182:5000`

## Setup

This folder was scaffolded manually because Flutter is not installed in the current workspace.

On a Flutter-enabled machine:

```bash
cd mobile_app
flutter pub get
flutter run
```

## Planned Next Steps

- microphone recording
- transcript history
- translation selection
- cleaner loading and retry states
- Android/iOS platform setup
