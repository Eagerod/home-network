import dateutil.parser
import json
import logging
import os
from datetime import datetime, timedelta

import requests
from flask import Flask, request


ALERT_EXPIRY = timedelta(hours=24)

# Simple application that will listen on a port, and will forward on messages
#   to the provided Slack account.
app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

default_channel = os.environ['SLACK_CHANNEL']
bot_host = os.environ['SLACK_HOST']
bot_url = '{}/message'.format(bot_host)


class AlertCache(object):
    def __init__(self):
        self.cache = {}

    def _key(self, item):
        return '{} - {} - {} - {}'.format(
            item['annotations']['message'],
            item['startsAt'],
            item['labels']['severity'],
            item['status'])


    def add(self, item):
        key = self._key(item)

        if key in self.cache:
            return False

        value = datetime.utcnow() + ALERT_EXPIRY
        self.cache[key] = value
        return True

    def purge(self):
        now = datetime.utcnow()
        for key in self.cache:
            if self.cache[key] < now:
                del self.cache[key]


alert_cache = AlertCache()


# Todo -- Update this to cache in one of the DBs, rather than just in memory.
@app.route('/incoming', methods=['GET', 'POST'])
def receive_internal_message():
    alert_cache.purge()

    alertmanager_payload = request.get_data()
    print('Received alert payload: {}'.format(alertmanager_payload))

    alertmanager_alerts = json.loads(alertmanager_payload)['alerts']

    for alert in alertmanager_alerts:
        if alert['status'] != 'firing':
            print('Skipping alert {} because it is not firing'.format(alert['annotations']['message']))
            continue

        if not alert_cache.add(alert):
            print('Skipping alert {} because it was recently sent'.format(alert['annotations']['message']))
            continue

        slack_message = '{} issue with cluster at {}.\n{}'.format(
            alert['labels']['severity'].capitalize(),
            dateutil.parser.parse(alert['startsAt']).strftime("%Y-%m-%dT%H:%M"),
            alert['annotations']['message']
        )
        # print(slack_message)
        requests.post(
            bot_url,
            data=slack_message,
            headers={
                'X-SLACK-CHANNEL-ID': default_channel
            }
        )

    return '', 200
