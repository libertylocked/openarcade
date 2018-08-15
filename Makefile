.PHONY: all node_modules compile test clean

all: node_modules compile

node_modules:
	scripts/npm-nvm.sh i -g npm@6
	scripts/npm-nvm.sh ci

compile:
	scripts/npm-nvm.sh run compile

test:
	scripts/npm-nvm.sh run coverage

clean:
	rm -rf build
	rm -rf node_modules
