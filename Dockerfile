# Use a smaller and newer base image with fewer known vulnerabilities
FROM python:3.10-slim-bookworm

# Set working directory
WORKDIR /app

# Install pip dependencies only
COPY requirements.txt .

# Upgrade pip and install only necessary Python dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app.py .
COPY templates/ ./templates/
COPY static/ ./static/

# Expose port
EXPOSE 5000

# Run the application with Gunicorn with more workers and timeout settings
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "--keep-alive", "5"]
