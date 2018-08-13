#!/bin/sh
NPM_PREFIX=$(npm config get prefix)
npm config delete prefix
source /usr/share/nvm/init-nvm.sh --install && \
	nvm install && \
    nvm use --delete-prefix && \
    npm run $1 && \
    nvm unalias default
npm config set prefix ${NPM_PREFIX}
