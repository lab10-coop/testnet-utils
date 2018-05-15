#!/bin/bash

# checks and sets up the go env (todo: doesn't belong here)
# installs tendermint and ethermint
# tries to be idempotent

set -e
set -u

if [ -z ${GOPATH+x} ]; then
	if grep -q "GOPATH" ~/.profile; then
		echo "### GOPATH occurs in ~/.profile, but is not set in this shell."
		echo "### You need to reload the environment or figure out what's the matter."
		exit 1
	fi

	echo "*** adding GOPATH to ~/.profile and bin to PATH"
	# assuming ~/go doesn't exist
	mkdir $HOME/go
	echo "# paths for go-lang"
	echo 'export GOPATH="$HOME/go"' >> $HOME/.profile
	echo 'export GOBIN="$HOME/go/bin"' >> $HOME/.profile
	echo 'export PATH:"$GOBIN:$PATH"' >> $HOME/.profile
	echo
	echo "*** you need to reload .profile (or re-login) and then re-run this script"
	exit
fi

if ! `which glide > /dev/null`; then
	echo "*** installing glide..."
	curl https://glide.sh/get | sh
fi

if ! `which tendermint > /dev/null`; then
	echo "*** installing tendermint 0.14.0"
	go get -d github.com/tendermint/tendermint/cmd/tendermint
	cd $HOME/go/src/github.com/tendermint/tendermint
	git checkout v0.14.0
	glide install
	go install github.com/tendermint/tendermint/cmd/tendermint
	cd -
fi

if ! `which ethermint > /dev/null`; then
	echo "*** installing ethermint"
	go get -d github.com/tendermint/ethermint/cmd/ethermint
	cd $HOME/go/src/github.com/tendermint/ethermint

	# make does both build and install, install does only install (one would expect it the other way round)
	# explicitly doing both anyway as this may change in future
	make && make install
	cd -
fi

echo "*** all done"
