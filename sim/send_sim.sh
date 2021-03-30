#!/bin/sh

KEY=$1
NUM_SIM=$2

# Session Name
SESSION="SimTest"
SESSIONEXISTS=$(tmux list-sessions | grep $SESSION)


# Check if session exists
if [ "$SESSIONEXISTS" != "" ]
then
    # Select the open window
    tmux select-window -t $SESSION
    # Check if selected elevator exists
    NUM_PANES=$(tmux display-message -p '#{window_panes}')
    if [ $NUM_SIM -lt $NUM_PANES ]
    then
        # Send key to elevator
        tmux select-pane -t $NUM_SIM  
        tmux send-keys -t $SESSION:'Main' $KEY
    else
        echo "Elevator number exceeds number of simulators!"
    fi
else
    echo "Simulator not started!"
fi