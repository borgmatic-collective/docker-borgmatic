#!/usr/bin/env python3
import sys
import apprise

# Create an Apprise object
apobj = apprise.Apprise()

# Add notification services (replace the URLs with your own).
apobj.add('slack://token_a/token_b/token_c')
apobj.add('telegram://bot_token/chat_id')

# Send a message to all configured services
title = sys.argv[1]
message = sys.argv[2]
apobj.notify(title=title, body=message)