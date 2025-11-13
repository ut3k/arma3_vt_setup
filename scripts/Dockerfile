# Use an official Python runtime as the base image
FROM python:3.11-alpine

# Set workdir to /data (we will mount host dir here)
WORKDIR /data

# Avoid creating .pyc files
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install build deps (minimal) and cleanup

# Copy requirements and install
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY sortowanie.py /usr/local/bin/sortowanie.py
RUN chmod +x /usr/local/bin/sortowanie.py

COPY tworzenie_presetów.py /usr/local/bin/tworzenie_presetów.py
RUN chmod +x /usr/local/bin/tworzenie_presetów.py

# Default command runs the script (interactive)
ENTRYPOINT ["sh", "-c", "python /usr/local/bin/sortowanie.py && python /usr/local/bin/tworzenie_presetów.py"]