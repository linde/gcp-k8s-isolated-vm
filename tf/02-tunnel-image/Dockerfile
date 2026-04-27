FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends iptables iproute2 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY image-files/proxied_test.py .
COPY image-files/entrypoint.sh .

RUN chmod +x entrypoint.sh
RUN pip install --no-cache-dir gunicorn flask
ENTRYPOINT ["./entrypoint.sh"]

