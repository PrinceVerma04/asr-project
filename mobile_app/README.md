# ASR Mobile App

Simple Flutter client for the ASR backend running on your college server.

## Current Features

- set backend URL
- choose an audio file from the phone
- live audio recording
- send audio to `/transcribe`
- show transcript response
- show saved output path returned by the server
- transcript history cards
- theme toggle with light, dark, and system modes
- animated panels and loading states

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

## Extra Notes

- The recording feature uses the `record` package.
- On Android and iOS, microphone permission setup will be required in the platform project files after running Flutter tooling.
- If you are testing on a physical phone, keep the backend URL pointed to your reachable server IP, for example:

`http://192.168.162.182:5000`

## Planned Next Steps

- translation selection
- Android/iOS platform setup
- persistent local transcript history
- share and export actions
