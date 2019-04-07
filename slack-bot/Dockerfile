FROM ncfgbase

RUN \
    apt-get update -y && \
    apt-get install -y python-pip

COPY requirements.txt /var/lib/bot/requirements.txt

RUN python -m pip install -r /var/lib/bot/requirements.txt

COPY bot.py /var/lib/bot/bot.py

ENV FLASK_APP /var/lib/bot/bot.py
ENV FLASK_ENV development

CMD ["flask", "run", "--host", "0.0.0.0", "-p", "8080"]
