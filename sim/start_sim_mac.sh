#!/bin/sh
SIM_PATH=$1
SIM_PORT=$2
SIM_FLOORS=$3
osascript -e 'tell app "Terminal"
    do script "'$SIM_PATH' --port '$SIM_PORT' --floors '$SIM_FLOORS'"
end tell'