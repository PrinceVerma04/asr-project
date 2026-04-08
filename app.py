from argparse import ArgumentParser
import os
from pathlib import Path
import tempfile

from flask import Flask, jsonify, render_template, request
import torch
from transformers import AutoProcessor, CohereAsrForConditionalGeneration
from transformers.audio_utils import load_audio
from werkzeug.utils import secure_filename

MODEL_ID = os.environ.get("MODEL_ID", "CohereLabs/cohere-transcribe-03-2026")
BASE_DIR = Path(__file__).resolve().parent
AUDIO_DIR = BASE_DIR / "audio"
OUTPUT_DIR = BASE_DIR / "output"
DEFAULT_AUDIO_NAME = os.environ.get("DEFAULT_AUDIO_NAME", "output.wav")
DEFAULT_LANGUAGE = os.environ.get("DEFAULT_LANGUAGE", "en")
MAX_UPLOAD_MB = int(os.environ.get("MAX_UPLOAD_MB", "50"))
USE_CUDA = torch.cuda.is_available()
DEVICE = torch.device("cuda" if USE_CUDA else "cpu")
MODEL_DTYPE = torch.float16 if USE_CUDA else torch.float32

processor = None
model = None
app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024

if USE_CUDA:
    torch.backends.cudnn.benchmark = True
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True


def get_model():
    global processor, model

    if processor is None:
        try:
            processor = AutoProcessor.from_pretrained(MODEL_ID)
        except OSError as exc:
            raise RuntimeError(
                "Unable to access the Cohere model. Accept the model access terms on "
                "Hugging Face, then use a token with read access and public gated "
                "repository access enabled. Log in with `huggingface-cli login` or "
                "`hf auth login` before running."
            ) from exc

    if model is None:
        try:
            model = CohereAsrForConditionalGeneration.from_pretrained(
                MODEL_ID,
                torch_dtype=MODEL_DTYPE,
            )
            model.to(DEVICE)
            model.eval()
        except OSError as exc:
            raise RuntimeError(
                "Unable to load the Cohere model. Accept the model access terms on "
                "Hugging Face, then use a token with read access and public gated "
                "repository access enabled. Log in with `huggingface-cli login` or "
                "`hf auth login` before running."
            ) from exc

    return processor, model


def resolve_audio_path(audio_path: str | None) -> Path:
    if not audio_path:
        path = AUDIO_DIR / DEFAULT_AUDIO_NAME
    else:
        path = Path(audio_path)
        if not path.is_absolute():
            candidate = AUDIO_DIR / path
            path = candidate if candidate.exists() else (BASE_DIR / path)

    if not path.exists():
        raise FileNotFoundError(
            f"Audio file not found: {path}\n"
            f"Place your file in {AUDIO_DIR} or pass an absolute path with --audio."
        )

    return path


def transcribe(audio_path: Path, lang: str = DEFAULT_LANGUAGE) -> str:
    processor, model = get_model()
    audio = load_audio(str(audio_path), sampling_rate=16000)

    inputs = processor(audio, sampling_rate=16000, return_tensors="pt", language=lang)
    prepared_inputs = {}
    for key, value in inputs.items():
        if torch.is_tensor(value) and value.is_floating_point():
            prepared_inputs[key] = value.to(device=model.device, dtype=model.dtype)
        elif torch.is_tensor(value):
            prepared_inputs[key] = value.to(device=model.device)
        else:
            prepared_inputs[key] = value

    with torch.inference_mode():
        outputs = model.generate(**prepared_inputs, max_new_tokens=256)
        text = processor.decode(outputs, skip_special_tokens=True)
    if isinstance(text, list):
        text = text[0]

    return text.strip()


def save_transcription(audio_path: Path, text: str) -> Path:
    OUTPUT_DIR.mkdir(exist_ok=True)
    output_path = OUTPUT_DIR / f"{audio_path.stem}.txt"
    output_path.write_text(text + "\n", encoding="utf-8")
    return output_path


def build_parser() -> ArgumentParser:
    parser = ArgumentParser(description="Transcribe audio with Cohere Transcribe.")
    parser.add_argument(
        "--audio",
        help=(
            "Audio filename inside the audio folder, relative project path, or "
            "absolute path. Default: audio/output.wav"
        ),
    )
    parser.add_argument(
        "--lang",
        default="en",
        help=f"Language code for transcription. Default: {DEFAULT_LANGUAGE}",
    )
    parser.add_argument(
        "--web",
        action="store_true",
        help="Run the Flask web interface.",
    )
    parser.add_argument(
        "--host",
        default="127.0.0.1",
        help="Flask host. Default: 127.0.0.1",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=5000,
        help="Flask port. Default: 5000",
    )
    return parser


@app.get("/")
def index():
    return render_template(
        "index.html",
        model_id=MODEL_ID,
        default_language=DEFAULT_LANGUAGE,
        max_upload_mb=MAX_UPLOAD_MB,
        device=str(DEVICE),
    )


@app.get("/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "model": MODEL_ID,
            "device": str(DEVICE),
            "default_language": DEFAULT_LANGUAGE,
        }
    )


@app.post("/transcribe")
def transcribe_audio():
    uploaded_file = request.files.get("audio")
    language = request.form.get("lang", DEFAULT_LANGUAGE)

    if uploaded_file is None or uploaded_file.filename == "":
        return jsonify({"error": "Please upload an audio file."}), 400

    safe_name = secure_filename(uploaded_file.filename) or "uploaded_audio.wav"

    with tempfile.NamedTemporaryFile(delete=False, suffix=Path(safe_name).suffix or ".wav") as temp_file:
        temp_path = Path(temp_file.name)

    try:
        uploaded_file.save(temp_path)
        text = transcribe(temp_path, lang=language)
        output_path = save_transcription(Path(safe_name), text)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500
    finally:
        if temp_path.exists():
            temp_path.unlink()

    return jsonify(
        {
            "model": MODEL_ID,
            "audio_file": safe_name,
            "language": language,
            "text": text,
            "saved_to": str(output_path),
        }
    )


def run_cli(audio_arg: str | None, lang: str) -> None:
    audio_path = resolve_audio_path(audio_arg)
    result = transcribe(audio_path, lang=lang)
    output_path = save_transcription(audio_path, result)

    print(f"Model: {MODEL_ID}")
    print(f"Audio file: {audio_path}")
    print(f"Saved transcription: {output_path}")
    print("Transcription:", result)


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.web:
        get_model()
        app.run(debug=False, use_reloader=False, host=args.host, port=args.port)
        return

    run_cli(args.audio, args.lang)


if __name__ == "__main__":
    main()
