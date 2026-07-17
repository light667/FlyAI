# Vercel Serverless entry point for FastAPI
# Vercel @vercel/python builder looks for a WSGI/ASGI app at this path
# and serves it as a serverless function.

import sys
import os

# Add the backend root to sys.path so `from app.xxx import ...` works
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.main import app  # noqa: F401 — Vercel picks up `app` automatically
