NPM_PREFIX = $(shell sh -cl 'npm config get prefix')

all:
	npm config delete prefix
	bash -l -c 'source /usr/share/nvm/init-nvm.sh --install && \
		nvm install && nvm use && \
		npm i -g npm@6 && \
		npm i && npm run compile'
	npm config set prefix $(NPM_PREFIX)

clean:
	rm -rf build
