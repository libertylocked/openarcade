.PHONY: all test clean

all:
	scripts/run-script-nvm.sh compile

test:
	scripts/run-script-nvm.sh coverage

clean:
	rm -rf build
