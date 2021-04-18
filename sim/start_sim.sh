#!/bin/sh

SIM_PATH=$1
SIM_PORT=$2
SIM_FLOORS=$3
NUM_SIMS=$4

SIM_OPTS=""
# shift x 4 moves out the first 4 args
shift
shift
shift
shift
for var in $@
do
    SIM_OPTS=$SIM_OPTS" Space "$var
done

# Set Session Name
SESSION="SimTest"
SESSIONEXISTS=$(tmux list-sessions | grep $SESSION)
SESSIONCONNECTED=$(tmux list-sessions | grep $SESSION | grep 'attached')

# Only create tmux session if it doesn't already exist
if [ "$SESSIONEXISTS" != "" ]
then
    # If someone is connected to the session, don't close it, but just kill the processes
    if [ -z "$SESSIONCONNECTED" ]
    then
        tmux kill-session -t $SESSION
    else
        tmux new-window -t $SESSION:1
        tmux select-window -t $SESSION:'Main'
        tmux kill-window -t $SESSION:'Main'
        tmux new-window -t $SESSION
    fi
fi
tmux kill-window -t $SESSION:1

# Start new session with specified name
tmux new-session -d -s $SESSION

# Name first winow and start first simulator
tmux rename-window -t $SESSION:0 'Main'
tmux select-pane -t 0
tmux send-keys -t $SESSION:'Main' $SIM_PATH ' --port ' $SIM_PORT ' --numfloors ' $SIM_FLOORS ' ' $SIM_OPTS C-m


# Create NUM_SIMS-1 more panes and simulators
i=1
while [ "$i" -lt "$NUM_SIMS" ]; do
    tmux split-window -t $SESSION -v
    tmux send-keys -t $SESSION:'Main' $SIM_PATH ' --port ' $((SIM_PORT + i)) ' --numfloors ' $SIM_FLOORS ' ' $SIM_OPTS C-m
    tmux select-layout -t $SESSION tiled
    i=$(( i + 1))
done


#echo $# #gives number of arguments received

# Setup an additional shell
#tmux new-window -t $SESSION:1 -n 'Shell'
#tmux send-keys -t 'Shell' 'echo hello' C-m # Switch to bind script?

# Attach Session, on the Main window
#tmux attach-session -t $SESSION:0

