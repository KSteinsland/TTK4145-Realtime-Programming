#!/bin/sh


# Session Name
SESSION="ClusterTest"
SESSIONEXISTS=$(tmux list-sessions | grep $SESSION)
SESSIONCONNECTED=$(tmux list-sessions | grep $SESSION | grep 'attached')

# Only close tmux session if it does  exist
if [ "$SESSIONEXISTS" != "" ]
then
    # If someone is connected to the session, don't close it
    if [ -z "$SESSIONCONNECTED" ]
    then
        tmux kill-session -t $SESSION
    fi
fi
