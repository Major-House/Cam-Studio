FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install system deps and ffmpeg (required by many features)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    build-essential \
    gcc \
    libpq-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Render / other hosts provide $PORT. Default to 10000 for local runs.
ENV HOST=0.0.0.0
ENV PORT=10000
EXPOSE ${PORT}

# Use the included entrypoint (originally in Procfile) which starts Flask and background threads.
# Running python virtual_cam_bridge.py keeps the bridge idle loop and features that run only under __main__.
CMD ["bash", "-lc", "python virtual_cam_bridge.py"]
