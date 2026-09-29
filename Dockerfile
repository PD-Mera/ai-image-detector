# syntax=docker/dockerfile:1

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/opt/aidetect \
    XDG_CACHE_HOME=/opt/aidetect/.cache \
    HF_HOME=/opt/aidetect/.cache/huggingface \
    HF_HUB_CACHE=/opt/aidetect/.cache/huggingface/hub \
    TOKENIZERS_PARALLELISM=false

WORKDIR /app

# Keep the model cache in the image so runtime does not need network access.
RUN apt-get update \
    && apt-get install --no-install-recommends -y libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/aidetect/.cache/huggingface/hub /app

COPY pyproject.toml README.md ./
COPY aidetector ./aidetector

RUN python -m pip install --upgrade pip \
    && python -m pip install --no-cache-dir ".[api]"

# Download the exact pretrained assets used by the default UnivFD backend.
# open_clip chooses the same cache and pretrained source at runtime because the
# HOME/HF_* variables above remain set in the final image.
RUN python -c "from open_clip.pretrained import download_pretrained, get_pretrained_cfg; cfg = get_pretrained_cfg('ViT-L-14', 'openai'); target = download_pretrained(cfg); print('Cached CLIP weights:', target)" \
    && python -c "from huggingface_hub import hf_hub_download; target = hf_hub_download(repo_id='siddharthksah/deepsafe-weights', filename='universalfakedetect/fc_weights.pth'); print('Cached UnivFD head:', target)"

# Prevent accidental model downloads when the service is deployed offline.
ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1 \
    HF_DATASETS_OFFLINE=1 \
    HF_HUB_DISABLE_TELEMETRY=1

EXPOSE 8000

CMD ["aidetect", "api", "--host", "0.0.0.0", "--port", "8000", "--backend", "univfd", "--device", "cpu"]
