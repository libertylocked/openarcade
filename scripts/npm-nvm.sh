#!/bin/sh

# This script runs NPM using a version of node specified in nvmrc
# npm-nvm.sh <command>
# Examples:
# - npm-nvm.sh install
# - npm-nvm.sh run build

NPM_PREFIX=$(npm config get prefix)
npm config delete prefix
source /usr/share/nvm/init-nvm.sh --install && \
  nvm install && \
  nvm use --delete-prefix && \
  npm $@ && \
  nvm unalias default
npm config set prefix ${NPM_PREFIX}
