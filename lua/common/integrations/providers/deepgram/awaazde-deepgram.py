from deepgram import Deepgram
import asyncio
import sys

DEEPGRAM_API_KEY = 'a4afbcf25df9905827a0aafcb8b0935c629b8ed3'

# Mimetype for the file you want to transcribe
MIMETYPE = 'audio/wav'


async def get_transcript(file):
    # Initialize the Deepgram SDK
    deepgram = Deepgram(DEEPGRAM_API_KEY)

    # Open the audio file
    audio = open(file, 'rb')
    # Set the source
    source = {
        'buffer': audio,
        'mimetype': MIMETYPE
    }
    # Record the start time
    # Send the audio to Deepgram and get the response
    response = await asyncio.create_task(
        deepgram.transcription.prerecorded(
            source,
            {
                'model': 'nova-2',
                'language': 'hi'
            }
        )
    )

    # Write only the transcript to the console
    sys.stdout.write(response["results"]["channels"][0]["alternatives"][0]["transcript"])


if __name__ == "__main__":
    file = sys.argv[1]
    filename = file.split('/')[-1]
    val = asyncio.run(get_transcript(file))
