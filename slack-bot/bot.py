import os

from flask import Flask, request
from slackclient import SlackClient

# Simple application that will listen on a port, and will forward on messages
#   to the provided Slack account.
app = Flask(__name__)

slack_client = SlackClient(os.environ['SLACK_API_KEY'])
default_channel = os.environ['DEFAULT_CHANNEL']

@app.route('/message', methods=['POST'])
def receive_internal_message():
    message_body = request.get_data()
    channel = request.headers.get('X-SLACK-CHANNEL-ID') or default_channel

    slack_client.api_call('chat.postMessage', channel=channel, text=message_body)

    return '', 200
