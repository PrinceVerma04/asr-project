# ASR Project

Speech-to-text pipeline built around `CohereLabs/cohere-transcribe-03-2026`, with:

- CLI transcription
- Flask web upload UI
- output text file generation
- a Hugging Face deployment path for mobile apps

## Features

- Transcribe local audio files
- Upload audio through a simple web page
- Save transcripts into the `output/` folder
- Use GPU automatically when CUDA is available
- Deploy toward Hugging Face Inference Endpoints for mobile integration

## Project Structure

- `app.py`: main application for CLI and web modes
- `audio/`: input audio files
- `output/`: generated transcription files
- `templates/`: Flask HTML template
- `hf_endpoint_client.py`: example client for a hosted endpoint
- `requirements.txt`: Python dependencies

## Requirements

- Python 3.12+
- Hugging Face access to `CohereLabs/cohere-transcribe-03-2026`
- A Hugging Face token with read access and public gated repository access enabled

## Local Setup

```bash
git clone https://github.com/PrinceVerma04/asr-project.git
cd asr-project
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Log in to Hugging Face:

```bash
huggingface-cli login
```

## CLI Usage

Use the default audio file:

```bash
python app.py
```

Use a specific file from the `audio/` folder:

```bash
python app.py --audio output_2.wav
```

Use an absolute file path:

```bash
python app.py --audio /full/path/to/file.wav
```

Set a language code:

```bash
python app.py --audio output.wav --lang en
```

## Web Interface

Start the web app:

```bash
python app.py --web
```

Open:

`http://127.0.0.1:5000`

Available routes:

- `/`: upload UI
- `/transcribe`: audio transcription API
- `/health`: health check endpoint

## Environment Variables

You can customize runtime behavior with:

- `MODEL_ID`: model repo id
- `DEFAULT_AUDIO_NAME`: default local audio file
- `DEFAULT_LANGUAGE`: default language code
- `MAX_UPLOAD_MB`: upload limit for web mode

Example:

```bash
export DEFAULT_LANGUAGE=en
export MAX_UPLOAD_MB=50
python app.py --web
```

## Output Files

If you transcribe:

`audio/output.wav`

The transcript is saved as:

`output/output.txt`

If you transcribe:

`audio/output_2.wav`

The transcript is saved as:

`output/output_2.txt`

## GPU Notes

- The app uses CUDA automatically when available.
- On GPU, it prefers `float16` for faster inference and lower memory usage.
- The Cohere model is large, so CPU inference is much slower than GPU inference.
- In web mode, the model is preloaded once at startup to make requests faster afterward.

## Mobile App Deployment Path

For a production mobile app, use:

- GitHub for source code
- Hugging Face Inference Endpoints for model serving
- your mobile app as the frontend

Recommended flow:

1. Record or upload audio from the phone
2. Send the file to your hosted endpoint
3. Receive the transcript JSON
4. Display and store the result in the app

The included `hf_endpoint_client.py` shows the same request pattern your mobile app can use.

## Hugging Face Deployment Notes

For a mobile app, Hugging Face **Inference Endpoints** are a better fit than Spaces because they provide a stable hosted API for inference workloads.

Useful docs:

- https://huggingface.co/docs/inference-endpoints/main/en/index
- https://huggingface.co/docs/hub/en/spaces-sdks-docker

## Endpoint Client Example

Set:

```bash
export HF_ENDPOINT_URL="https://your-endpoint-url"
export HF_TOKEN="your_huggingface_token"
```

Run:

```bash
python hf_endpoint_client.py
```
