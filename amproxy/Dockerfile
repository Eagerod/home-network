FROM python:3.7-alpine

COPY requirements.txt /var/lib/bot/requirements.txt

RUN python3 -m pip install -r /var/lib/bot/requirements.txt

COPY server.py /var/lib/server/server.py

ENV FLASK_APP /var/lib/server/server.py

CMD ["flask", "run", "--host", "0.0.0.0", "-p", "80"]
