# Livekit egress example

## Requirements

- [Docker](https://docker.com)
- [Livekit-cli](https://github.com/livekit/livekit-cli)

## Running

1. Copy `.env.local.example` to `.env.local`. [^1]

[^1]: I use [`mise`](https://mise.jdx.dev/) to load environment variables from `.env.local` into my shell, [`direnv`](https://direnv.net/) or [similar](https://gist.github.com/camflan/e94492b44701c1e5282a93ec124711ca) will also work.

1. Start stack

    ```bash
      docker compose up
    ```

2. Run stream script

    ```bash
    ./start-web-stream.sh --destination=rtmps://RTMPS_INGEST_URL/STREAM_KEY --source URL_TO_RECORD
    ```

    This script will configure a project, set up an egress config, create an egress and monitor it's status. Exiting the script should also kill the egress. Script should handle Egress failure and completion as well.
