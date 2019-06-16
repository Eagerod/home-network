import dateutil.parser
import json
import logging
import os

import requests
from flask import Flask, request

# Simple application that will listen on a port, and will forward on messages
#   to the provided Slack account.
app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

default_channel = os.environ['SLACK_CHANNEL']
bot_host = os.environ['SLACK_HOST']
bot_url = '{}/message'.format(bot_host)


# Todo -- Update this to keep track of events its already fired.
@app.route('/incoming', methods=['GET', 'POST'])
def receive_internal_message():
    alertmanager_payload = request.get_data()
    print('Received alert payload: {}'.format(alertmanager_payload))

    alertmanager_alerts = json.loads(alertmanager_payload)['alerts']

    for alert in alertmanager_alerts:
        if alert['status'] != 'firing':
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
