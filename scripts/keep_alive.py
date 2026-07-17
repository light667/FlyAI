import time
import httpx
import sys

# Replace with your actual Render deployment API URL
RENDER_URL = "https://flyai-backend.onrender.com/health"

def ping_backend():
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Pinging backend: {RENDER_URL}...")
    try:
        response = httpx.get(RENDER_URL, timeout=10.0)
        if response.status_code == 200:
            print(f"Success! Response 200: {response.json()}")
        else:
            print(f"Warning: Received status code {response.status_code}")
    except Exception as e:
        print(f"Error pinging backend: {e}", file=sys.stderr)

if __name__ == "__main__":
    # If run as a continuous loop daemon locally
    print("Starting Keep Alive loop daemon... Press Ctrl+C to stop.")
    while True:
        ping_backend()
        # Sleep for 10 minutes (600 seconds)
        time.sleep(600)
