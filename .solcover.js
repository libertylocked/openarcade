module.exports = {
  port: 8555,
  copyPackages: ['openzeppelin-solidity'],
  skipFiles: [
    'Migrations.sol',
    'games/Starter.sol',
    'mocks',
    '.generated',
  ],
  compileCommand: 'npm run compile',
  testCommand: '../node_modules/.bin/truffle test --network coverage',
};
