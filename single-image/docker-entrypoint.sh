#!/usr/bin/env bash

set -euxo pipefail

# Clean out tmp
rm -rf /home/egress/tmp/*

# Start pulseaudio
rm -rf /var/run/pulse /var/lib/pulse /home/egress/.config/pulse /home/egress/.cache/xdgr/pulse
pulseaudio -D --verbose --exit-idle-time=-1 --disallow-exit

# start redis
redis-server &

# start livekit-server
livekit-server --config /server-config.yaml --dev &

export PATH=${PATH}:/chrome
export XDG_RUNTIME_DIR=/home/egress/.cache/xdgr
export CHROME_DEVEL_SANDBOX=/usr/local/sbin/chrome-devel-sandbox

export LIVEKIT_URL=http://127.0.0.1:7880
export LIVEKIT_API_KEY=devkey
export LIVEKIT_API_SECRET=secret

# Run egress service
egress --config /egress-config.yaml &

sleep 10

if [[ "$DESTINATION_URL" == "" || "$SOURCE_URL" == "" ]]; then
    echo "DESTINATION_URL and SOURCE_URL must be provided"
    exit 1
fi

/start-web-stream.sh --destination $DESTINATION_URL --source $SOURCE_URL
