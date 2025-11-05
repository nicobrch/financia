# Multi-stage build for Financia API
# Uses Python 3.11 and UV package manager

# Stage 1: Builder
FROM python:3.12-slim as builder

WORKDIR /app

# Install UV package manager
RUN pip install --no-cache-dir uv

# Copy dependency files
COPY pyproject.toml ./
COPY uv.lock* ./

# Install dependencies (creates .venv)
RUN uv sync --no-dev --frozen 2>/dev/null || uv sync --no-dev

# Stage 2: Runtime
FROM python:3.12-slim

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY main.py ./

# Set PATH to use virtual environment
ENV PATH="/app/.venv/bin:$PATH"

# Set default port (Cloud Run will override with PORT env var)
ENV PORT=8000

# Expose port
EXPOSE 8000

# Run the application
# Use shell form to allow PORT environment variable substitution
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT}
