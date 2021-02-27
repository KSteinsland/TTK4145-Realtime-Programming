#!/bin/sh

#./SimElevatorServer </dev/null &>/dev/null &

SIM_PATH=$1
SIM_PORT=$2
SIM_FLOORS=$3

x-terminal-emulator -e $SIM_PATH --port $SIM_PORT --floors $SIM_FLOORS
