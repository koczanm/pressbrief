FROM python:3.6-slim

RUN apt-get update \
    && apt-get install -y \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    cron \
    && rm -rf /var/lib/apt/lists/*

COPY Pipfile Pipfile.lock /app/
WORKDIR /app

RUN python -m pip install --upgrade pip \
    && python -m pip install pipenv \
    && python -m pipenv lock --requirements > requirements.txt \
    && python -m pip install --no-cache-dir -r requirements.txt

COPY scripts/container-startup.sh scripts/pressbrief-execution.sh config.yaml pressbrief/. /app/
RUN chmod +x container-startup.sh pressbrief-execution.sh

CMD ["/app/container-startup.sh"] 