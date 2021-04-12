#!/bin/sh

REPO_PATH=$1
DRIVER_PORT=$2
NUM_NODES=$3

# Session Name
SESSION="ClusterTest"
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

# Name first winow and start first node
tmux rename-window -t $SESSION:0 'Main'
tmux select-pane -t 0
tmux send-keys -t $SESSION:'Main' 'cd ' $REPO_PATH ' ' C-m
tmux send-keys -t $SESSION:'Main' 'export ' 'EL_DRIVER_PORT='$DRIVER_PORT Enter
tmux send-keys -t $SESSION:'Main' 'iex --name node1@127.0.0.1 -S mix' ' ' C-m


# Create NUM_NODES-1 more panes and nodes
for ((i=1;i<$NUM_NODES;i++))
do
    sleep 1
    tmux split-window -t $SESSION -v

    tmux send-keys -t $SESSION:'Main' 'cd ' $REPO_PATH ' ' Enter
    tmux send-keys -t $SESSION:'Main' 'export ' 'EL_DRIVER_PORT=' $((DRIVER_PORT + i)) Enter
    tmux send-keys -t $SESSION:'Main' 'iex --name node'$((1 + i))'@127.0.0.1 -S mix' ' ' C-m

    tmux select-layout -t $SESSION tiled
    
done

