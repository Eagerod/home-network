FROM python:3.7-alpine

COPY requirements.txt /var/lib/bot/requirements.txt

RUN python3 -m pip install -r /var/lib/bot/requirements.txt

COPY bot.py /var/lib/bot/bot.py

ENV FLASK_APP /var/lib/bot/bot.py

CMD ["flask", "run", "--host", "0.0.0.0", "-p", "80"]
