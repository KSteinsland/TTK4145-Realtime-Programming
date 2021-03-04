#!/bin/sh

SIM_PATH=$1
SIM_PORT=$2
SIM_FLOORS=$3
NUM_SIMS=$4

# Set Session Name
SESSION="SimTest"
SESSIONEXISTS=$(tmux list-sessions | grep $SESSION)
SESSIONCONNECTED=$(tmux list-sessions | grep $SESSION | grep "attached")

# Only create tmux session if it doesn't already exist
if [ "$SESSIONEXISTS" != "" ]
then
    # If someone is connected to the session, don't close it, but just kill the processes
    if ["$SESSIONCONNECTED" == ""]
    then
        tmux kill-session -t $SESSION
    else
        kill -9 `pgrep SimElevatorServer`
        tmux select-window -t $SESSION
        tmux kill-pane -a -t 0
    fi
fi

# Start new session with specified name
tmux new-session -d -s $SESSION

# Name first winow and start first simulator
tmux rename-window -t 0 'Main'
tmux send-keys -t 'Main' $SIM_PATH ' --port ' $SIM_PORT ' --numfloors ' $SIM_FLOORS C-m

# Create NUM_SIMS-1 more panes and simulators
for ((i=1;i<$NUM_SIMS;i++))
do
    tmux split-window -v
    tmux send-keys -t 'Main' $SIM_PATH ' --port ' $((SIM_PORT + i)) ' --numfloors ' $SIM_FLOORS C-m
    tmux select-layout -t $SESSION tiled
done


#echo $# #gives number of arguments received

# Setup an additional shell
#tmux new-window -t $SESSION:1 -n 'Shell'
#tmux send-keys -t 'Shell' 'echo hello' C-m # Switch to bind script?

# Attach Session, on the Main window
#tmux attach-session -t $SESSION:0

