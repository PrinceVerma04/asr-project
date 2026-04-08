from pathlib import Path
import os

import requests


def transcribe_with_endpoint(audio_path: str, endpoint_url: str, hf_token: str) -> dict:
    path = Path(audio_path)
    if not path.exists():
        raise FileNotFoundError(f"Audio file not found: {path}")

    with path.open("rb") as audio_file:
        response = requests.post(
            endpoint_url,
            headers={"Authorization": f"Bearer {hf_token}"},
            files={"audio": (path.name, audio_file, "audio/wav")},
            data={"lang": "en"},
            timeout=300,
        )

    response.raise_for_status()
    return response.json()


if __name__ == "__main__":
    endpoint_url = os.environ.get("HF_ENDPOINT_URL")
    hf_token = os.environ.get("HF_TOKEN")

    if not endpoint_url or not hf_token:
        raise RuntimeError(
            "Set HF_ENDPOINT_URL and HF_TOKEN before running this script."
        )

    result = transcribe_with_endpoint(
        audio_path="audio/output.wav",
        endpoint_url=endpoint_url,
        hf_token=hf_token,
    )
    print(result)
