#!/bin/bash

set -e
set -u

# requires root

add-apt-repository ppa:longsleep/golang-backports
apt-get update
apt-get install golang-go

