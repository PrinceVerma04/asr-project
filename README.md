# ASR Project

This repository provides a simple end-to-end audio transcription pipeline using `CohereLabs/cohere-transcribe-03-2026`.

For best performance, run it on a GPU machine with CUDA-enabled PyTorch.

## Project Flow

1. Put your audio file inside the [`audio/`](/home/princeverma/Desktop/ASR/asr-project/audio) folder.
2. Activate the virtual environment.
3. Run the transcription command.
4. Read the generated text file inside the [`output/`](/home/princeverma/Desktop/ASR/asr-project/output) folder.

## Folder Structure

- `audio/`: input audio files such as `.wav`
- `output/`: generated transcription text files
- `app.py`: main transcription script
- `requirements.txt`: Python dependencies

## Setup

```bash
cd /home/princeverma/Desktop/ASR/asr-project
source venv/bin/activate
```

If you need to install dependencies:

```bash
pip install -r requirements.txt
```

## Hugging Face Access

This project uses the gated model:

`CohereLabs/cohere-transcribe-03-2026`

Before running:

1. Accept access on the model page on Hugging Face.
2. Log in from the terminal:

```bash
huggingface-cli login
```

## Deploy On Hugging Face

For a mobile app, the recommended Hugging Face option is **Inference Endpoints** rather than Spaces.

Why:

- Inference Endpoints are designed for dedicated model serving.
- They are a better fit for mobile apps that need a stable API.
- Spaces are better for demos and browser apps.

Recommended production flow:

1. Push this repo to GitHub.
2. Create a Hugging Face Inference Endpoint for `CohereLabs/cohere-transcribe-03-2026`.
3. Choose a GPU instance for smoother inference.
4. Use your mobile app to call the endpoint URL.
5. Return the transcription JSON to the mobile UI.

Official docs:

- Inference Endpoints: https://huggingface.co/docs/inference-endpoints/main/en/index
- Spaces Docker docs: https://huggingface.co/docs/hub/en/spaces-sdks-docker

### Mobile App Architecture

- Mobile app records or uploads audio
- Mobile app sends audio to your Hugging Face endpoint
- Endpoint returns transcript text
- Mobile app shows and stores the result

### Endpoint Client Example

This repo includes:

`hf_endpoint_client.py`

Set your environment variables:

```bash
export HF_ENDPOINT_URL="https://your-endpoint-url"
export HF_TOKEN="your_huggingface_token"
```

Run:

```bash
python hf_endpoint_client.py
```

Your mobile app should follow the same pattern:

- send audio file
- send language code
- receive JSON response

## Run The Pipeline

Use the default audio file:

```bash
python app.py
```

Use a specific file inside `audio/`:

```bash
python app.py --audio output_2.wav
```

Use an absolute file path:

```bash
python app.py --audio /full/path/to/file.wav
```

Use another language code:

```bash
python app.py --audio output.wav --lang en
```

## Web Interface

Start the Flask app:

```bash
python app.py --web
```

Then open:

`http://127.0.0.1:5000`

Notes:

- In web mode, the model is preloaded once when the server starts.
- The first server startup can still take time because the model is large.
- On a GPU machine, inference is much faster than CPU.

## GPU Notes

- The app automatically uses CUDA if available.
- On GPU, it prefers `float16` for faster inference and lower VRAM usage.
- On CPU, this Cohere model is much slower because it is a large ASR model.

## Output

If you transcribe:

`audio/output.wav`

The result is saved as:

`output/output.txt`

If you transcribe:

`audio/output_2.wav`

The result is saved as:

`output/output_2.txt`
