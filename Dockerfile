FROM python:3.9-alpine

COPY ./main.py /app/main.py
WORKDIR /app

CMD ["python3", "main.py"]
