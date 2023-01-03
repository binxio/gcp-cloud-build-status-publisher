PROJECT:=laurens-knoll-sandbox

venv:
	@echo "Setting up virtual environment.."
	@python3 -m venv .venv && \
	. ./.venv/bin/activate && \
	pip install --quiet --upgrade pip && \
	pip install --quiet -r requirements.txt

run: venv
	@echo "Use CTRL+C to exit.."
	@PROJECT_ID=${PROJECT} ./.venv/bin/python main.py

build:
	@echo "Building image.."
	@docker build -t docker.local/gcp-cloud-build-status-publisher .