import json
import os

import bcrypt
import toml

from aiohttp import web
from aiohttp_basicauth import BasicAuthMiddleware
from feedgen.feed import FeedGenerator
from slacker import Slacker


def get_config():
    file_path = os.environ.get("SLACKFEEDER_CONFIG", "/etc/slackfeeder.toml")
    with open(file_path) as file:
        _config = toml.load(file)
    return _config


CONFIG = get_config()
SLACK = Slacker(CONFIG["Slack"]["token"])


def get_personal_space_history():
    whoami = SLACK.auth.test()
    im_id = [
        x for x in SLACK.im.list().body["ims"] if x["user"] == whoami.body["user_id"]
    ][0]["id"]
    return SLACK.im.history(im_id).body


def slack_history_to_feedgen(history):
    fg = FeedGenerator()

    fg.title(CONFIG["Feed"]["title"])
    fg.id(CONFIG["Feed"]["id"])
    fg.link(CONFIG["Feed"]["link"])
    fg.description(CONFIG["Feed"]["description"])

    for message in history["messages"]:
        message_id = message.get(
            "client_msg_id", f'{message.get("user")}--{message.get("ts")}'
        )

        fe = fg.add_entry()
        fe.id(message_id)

        title = None
        summary = None
        link = []

        for file in message.get("files", []):
            title = title or file.get("title", None)

            link_href = file.get("url_private", None)
            link_rel = "alternate"
            link.append(dict(href=link_href, rel=link_rel, title=title))

        for attachment in message.get("attachments", []):
            title = title or attachment.get("title", None)
            summary = summary or attachment.get("text", None)

            link_href = attachment.get("from_url", None)
            link_rel = "alternate"
            link.append(dict(href=link_href, rel=link_rel, title=title))

        fe.title(title or "Untitled")
        fe.summary(summary)
        fe.content(message["text"])
        fe.link(link)

    return fg


class CustomBasicAuth(BasicAuthMiddleware):
    async def check_credentials(self, username, password):
        try:
            stored_user, hash = CONFIG["Auth"]["htpasswd"].split(":")
            password_matches = bcrypt.checkpw(
                password.encode("utf-8"), hash.encode("utf-8")
            )
            return password_matches and username == stored_user
        except (ValueError, KeyError, TypeError):
            return False


async def handle_rss(request):
    history = get_personal_space_history()
    feed_generator = slack_history_to_feedgen(history)
    return web.Response(
        body=feed_generator.rss_str(pretty=True),
        charset="utf-8",
        content_type="application/rss+xml",
    )


async def handle_atom(request):
    history = get_personal_space_history()
    feed_generator = slack_history_to_feedgen(history)
    return web.Response(
        body=feed_generator.atom_str(pretty=True),
        charset="utf-8",
        content_type="application/atom+xml",
    )


def webapp():
    middlewares = []
    auth_config = CONFIG.get("Auth", False)
    if auth_config and auth_config.get("enable", False):
        print('Enable basic auth middleware')
        auth = CustomBasicAuth()
        middlewares.append(auth)

    app = web.Application(middlewares=middlewares)

    app.add_routes([web.get("/rss.xml", handle_rss), web.get("/atom.xml", handle_atom)])

    return app


def main():
    app = webapp()
    web.run_app(app, **CONFIG['Network'])


if __name__ == "__main__":
    main()
