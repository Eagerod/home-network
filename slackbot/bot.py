import logging
import os

from flask import Flask, request
from slack import WebClient
from slack.errors import SlackApiError

# Simple application that will listen on a port, and will forward on messages
#   to the provided Slack account.
app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)

slack_client = WebClient(token=os.environ['SLACK_API_KEY'])
default_channel = os.environ['DEFAULT_CHANNEL']


def finalize_error(api_return):
    if not api_return['ok']:
        # See if this is the server, or the sender's fault.
        if api_return['error'] == 'invalid_auth':
            logging.error('Slack API key is incorrectly configured.')
            return '', 500
        if api_return['error'] == 'not_authed':
            logging.error('Missing Slack API key.')
            return '', 500

        error = 'Unknown error from Slack: {}. Blaming the client.'.format(
            api_return['error']
        )
        logging.warning(error)
        return api_return['error'], 400

    return '', 200


@app.route('/health', methods=['GET'])
def health():
    return '', 200


@app.route('/message', methods=['POST'])
def receive_internal_message():
    message_body = request.get_data()

    if not message_body:
        return 'No message content', 400

    channel = request.headers.get('X-SLACK-CHANNEL-ID') or default_channel

    try:
        rv = slack_client.chat_postMessage(
            channel=channel,
            text=message_body.decode('utf-8'),
            unfurl_links=True,
            unfurl_media=True
        )
        return finalize_error(rv)
    except SlackApiError as e:
        return finalize_error(e.response)
