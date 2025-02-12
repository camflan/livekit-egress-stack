#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# How often to check egress for status changes
EGRESS_MONITOR_HEARTBEAT_SECONDS=10

# Egress Preset. 2=1080p 30fps
# Other configuration is possible by manually editing the config in `start_stream` fn
EGRESS_QUALITY_PRESET=2

# Capture egress ids here so we can stop them
ACTIVE_EGRESS_IDS=()

usage() {
  cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Quickly stream a URL to an RTMP endpoint
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] --destination URL --source URL

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
--destination   RTMP destination URL
--source        URL to record
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT

  for egress_id in "${ACTIVE_EGRESS_IDS[@]}"; do
      echo "Stopping Egress [$egress_id]…"
      lk egress stop --id=$egress_id
  done
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  source_url=""
  destination_url=""


  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    --destination)
        destination_url="${2-}"
        shift
        ;;
    --source)
        source_url="${2-}"
        shift
        ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${destination_url-}" ]] && die "Missing required parameter: destination"
  [[ -z "${source_url-}" ]] && die "Missing required parameter: source"

  return 0
}

get_or_create_project ()
{
    echo "Looking for existing project…"
    local projects=$(lk project list --json)

    if [[ $projects == No\ projects\ configured* ]]; then
        project_name="project-$RANDOM"
        echo "No project, creating new project [$project_name]…"

        lk project add $project_name \
            --api-key=$LIVEKIT_API_KEY \
            --api-secret=$LIVEKIT_API_SECRET \
            --url=$LIVEKIT_URL \
            --default
    else
        project_name=$(echo $projects | jq -r '.|arrays | .[0].Name')
        echo "Found [$project_name]"
    fi

    return 0
}

start_stream () {
    local _project=$1
    local _source=$2
    local _destination=$3

    tmpfile=$(mktemp /tmp/egress-config-XXXX)

    lk project list

    cat << EOF > $tmpfile
{
  "url": "$_source",
  "advanced": {
    "width": 1920,
    "height": 1080,
    "depth": 24,
    "framerate": 30,
    "key_frame_interval": 2,
    "video_bitrate": 8500,
    "video_codec": "H264_MAIN",
    "audio_bitrate": 320,
    "audio_codec": "AAC",
    "audio_frequency": 48000
  },
  "stream_outputs": [
    {
      "urls": [ "$_destination" ]
    }
  ]
}
EOF


    lk egress start --api-key=$LIVEKIT_API_KEY --api-secret=$LIVEKIT_API_SECRET --url=$LIVEKIT_URL --type=web --project=$_project $tmpfile

    rm -f $tmpfile
    return 0
}

beginswith() { case $2 in "$1"*) true;; *) false;; esac; }


get_egress_id ()
{
    local _project_name=$1
    local result=$(lk egress list --project=$1 --json)

    if [[ $result == project\ not\ found* ]]; then
        die "Egress not found!"
    fi

    # remove the ridiculous "Using project [project_name]" output from the "JSON" return value
    local prefix="Using project [$_project_name]"
    result=${result#"$prefix"}

    # Status codes,
    # -1: EGRESS_SUBMITTED (this is OUR status, not LiveKit's. Read below)
    # 0: EGRESS_STARTING
    # 1: EGRESS_ACTIVE
    # 2: EGRESS_ENDING
    # 3: EGRESS_COMPLETE
    # 4: EGRESS_FAILED
    #
    # JQ commands,
    # 1. Ensure we're only working with arrays
    # 2. If there's a null status, set to -1. This is *most likely* the Egress we just submitted
    # 3. Select EGRESS_SUBMITTED (our status from #2), EGRESS_STARTING, or EGRESS_ACTIVE items
    # 4. Sort so that hopefully the newest is first
    # 5. Return the egress_id for the first item
    #
    # NOTE: I tried sorting by .started_at but got inconsistent results for reasons I did not explore
    #
    active_egress_id=$(echo $result | jq -r '.|arrays | [ .[] | .status //= -1 | select(.status >= -1 and .status <= 1) ] | sort_by(.status) | .[0].egress_id')
    ACTIVE_EGRESS_IDS+=($active_egress_id)

    echo "Active Egress ID: $active_egress_id"
}

monitor_egress () {
    local _egress_id=$1
    local is_active=0

    while true; do
        result=$(lk egress list --id=$_egress_id --json)

        # EGRESS_STARTING
        if [[ $(echo $result | jq '.[0].status') == 0 ]]; then
            msg "Starting stream…"
        fi

        # EGRESS_STARTING
        if [[ $is_active -eq 0 && $(echo $result | jq '.[0].status') == 1 ]]; then
            msg "Now streaming…"
            is_active=1
        fi

        # EGRESS_COMPLETE
        if [[ $(echo $result | jq '.[0].status') == 3 ]]; then
            msg "Done streaming…"
            exit
        fi

        # EGRESS_FAILED
        if [[ $(echo $result | jq '.[0].status') == 4 ]]; then
            error=$(echo $result | jq '.[0].error')
            die "${error:-Unknown\ error}"
        fi

        sleep $EGRESS_MONITOR_HEARTBEAT_SECONDS
    done
}


main ()
{
    local project_name=""
    local source_url=""
    local destination_url=""
    local active_egress_id=""

    parse_params "$@"
    setup_colors
    get_or_create_project
    start_stream $project_name $source_url $destination_url
    get_egress_id $project_name
    monitor_egress $active_egress_id
}


main "$@"
