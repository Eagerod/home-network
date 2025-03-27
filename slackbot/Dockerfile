FROM registry.internal.aleemhaji.com/python:3.13-alpine AS base

RUN python3 -m pip install flake8==7.1.2

COPY bot.py /var/lib/bot/bot.py

RUN flake8 /var/lib/bot/

FROM base

COPY requirements.txt /var/lib/bot/requirements.txt

RUN python3 -m pip install -r /var/lib/bot/requirements.txt

COPY bot.py /var/lib/bot/bot.py

ENV FLASK_APP /var/lib/bot/bot.py

USER 1001

EXPOSE 8080

CMD ["flask", "run", "--host", "0.0.0.0", "-p", "8080"]
