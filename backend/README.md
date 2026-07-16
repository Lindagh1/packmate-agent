# Packmate Backend

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload --port 8000
pytest -v
```

Runtime dependencies are listed in `requirements.txt`. Development and test tools are in `requirements-dev.txt`.

## Container image

```bash
podman build -t packmate-backend:dev -f Containerfile .
```

The image installs only `requirements.txt` (no test dependencies).
