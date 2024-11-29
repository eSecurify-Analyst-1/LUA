import requests
import os
import sys
import json

if __name__ == "__main__":
    file = sys.argv[1]
    filename = file.split('/')[-1]

    url = "https://speechapi.navana.io/usecase/decode"

    payload = {'id': '88dc409c-a6d8-4a6c-af96-810f21af461a'}
    files = [
        ('file', (filename, open(file, 'rb'), 'audio/wav'))
    ]
    headers = {
        'Authorization': 'Bearer eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJjdXN0b21lcl9pZCI6ImZlYTQxNWNkLTUyMTctNDc5Yi1hMDFmLWE1MTA1NDQ5N2VlNiIsInByb2plY3RfaWQiOiIzNWRmNDdhZS0yOTllLTRmNGYtOTRmMi02NGQ5ZmEzMWFhYTgiLCJyb2xlIjoiZGVjb2RlIiwicGVybWlzc2lvbnMiOnsidXNlY2FzZSI6WyJkYyJdfX0.o7uPYfdFQzorIMx1x5ofMX9oYF7oQBa49Gj2STS17fooVf7CX5im8DYcFWzGFTOVy3QpHAOhYWsVCHpMxcgjng'
    }
    response = requests.request("POST", url, headers=headers, data=payload, files=files)
    res = json.loads(response.text)
    sys.stdout.write(res['transcription'][0])
