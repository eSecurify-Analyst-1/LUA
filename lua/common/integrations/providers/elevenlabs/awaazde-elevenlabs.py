import requests
import sys
from pydub import AudioSegment # sudo apt-get install ffmpeg
from io import BytesIO

KEY = "7a79d692c6ae0faa8a3383ebd8e19625"
VOICE_ID= "pMsXgVXv3BLzUgSXRplE"
CHUNK_SIZE = 1024
url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"

headers = {
  "Accept": "audio/mpeg",
  "Content-Type": "application/json",
  "xi-api-key": KEY
}

if __name__ == "__main__":
    text = sys.argv[1]
    file = sys.argv[2]
    data = {
      "text": text,
      "model_id": "eleven_multilingual_v1",
      "voice_settings": {
        "stability": 0.5,
        "similarity_boost": 0.85
      }
    }

    response = requests.post(url, json=data, headers=headers)
    if response.status_code == 200:
        # Convert the MPEG audio content to an AudioSegment
        audio_segment = AudioSegment.from_mp3(BytesIO(response._content))

        # Export the AudioSegment to a WAV file
        audio_segment.export(file, format="wav")
    else:
        print(f"Failed to fetch audio. Status code: {response.status_code}")
        print(response.text)
