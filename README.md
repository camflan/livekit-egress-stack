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

1. Create a project

    ```bash
      lk project add my-first-project --url ws://localhost:7881
    ```

4. Edit egress config (`./livekit-egress/web-egress.json`)

    1. Update `"url"` to match your render URL.
    1. Update `"stream_outputs.urls"`, set this to IVS LL ingest URL + streamKey.
    1. Update encoding options, the default is set using `"preset": 2` for 1080p 30fps. [Details](https://docs.livekit.io/home/egress/api/#encodingoptionspreset)

    ```json

    // Example JSON config
    {
      // This is the URL to record and stream to IVS
      "url": "https://videojs.github.io/autoplay-tests/plain/attr/autoplay-playsinline.html",
      "preset": 2, // 1080p 30fps
      "stream_outputs": [
        {
          "urls": [
            // ingestUrl_____________________________________________/streamKey_______________________________
            "rtmps://12b43c2.global-contribute.live-video.net:443/app/sk_us-east-1_NyDYJDySH9x4_GePFwYV1PSGOrj"
          ]
        }
      ]
    }
    ```

1. Start egress recording session

    ```bash
    lk egress start --type=web --project=my-first-project ./livekit-egress/web-egress.json
    ```

1. Stop egress session

    ```bash
    lk egress list
    # get ID from this list
    lk egress stop --id=STREAM_ID
    ```
