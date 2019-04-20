import logging
import os

from flask import Flask, request
from slackclient import SlackClient

# Simple application that will listen on a port, and will forward on messages
#   to the provided Slack account.
app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

slack_client = SlackClient(os.environ['SLACK_API_KEY'])
default_channel = os.environ['DEFAULT_CHANNEL']


@app.route('/message', methods=['POST'])
def receive_internal_message():
    message_body = request.get_data()
    if not message_body:
        return 'No message content', 400

    channel = request.headers.get('X-SLACK-CHANNEL-ID') or default_channel

    logging.info
    rv = slack_client.api_call('chat.postMessage',
                               channel=channel, text=message_body)

    if not rv['ok']:
        # See if this is the server, or the sender's fault.
        if rv['error'] == 'invalid_auth':
            logging.error('Slack API key is incorrectly configured.')
            return '', 500
        if rv['error'] == 'not_authed':
            logging.error('Missing Slack API key.')
            return '', 500

        error = 'Unknown error from Slack: {}. Blaming the client.'.format(
            rv['error']
        )
        logging.warning(error)
        return rv['error'], 400

    return '', 200
