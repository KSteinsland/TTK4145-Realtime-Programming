#!/bin/sh

SIM_PATH=$1
SIM_PORT=$2
SIM_FLOORS=$3

#./SimElevatorServer </dev/null &>/dev/null &
#x-terminal-emulator -e $SIM_PATH --port $SIM_PORT --floors $SIM_FLOORS

# Set Session Name
SESSION="SimTest"
SESSIONEXISTS=$(tmux list-sessions | grep $SESSION)

# Only create tmux session if it doesn't already exist
if [ "$SESSIONEXISTS" != "" ]
then
    tmux kill-session -t $SESSION
fi

# Start New Session with our name
tmux new-session -d -s $SESSION

# Name first Pane and start simulator
tmux rename-window -t 0 'Main'
tmux send-keys -t 'Main' $SIM_PATH ' --port ' $SIM_PORT ' --numfloors ' $SIM_FLOORS C-m

# Setup an additional shell
#tmux new-window -t $SESSION:1 -n 'Shell'
#tmux send-keys -t 'Shell' 'echo hello' C-m # Switch to bind script?

# Attach Session, on the Main window
#tmux attach-session -t $SESSION:0

