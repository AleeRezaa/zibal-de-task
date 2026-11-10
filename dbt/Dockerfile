FROM python:3.12-slim
WORKDIR /dbt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV DBT_PROFILES_DIR=/dbt
# run through sh: no execute bit needed (files come from a Windows checkout)
CMD ["sh", "run.sh"]