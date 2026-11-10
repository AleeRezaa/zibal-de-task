FROM python:3.12-slim
WORKDIR /tools
RUN pip install --no-cache-dir requests==2.32.3
COPY . .
CMD ["python", "setup.py"]