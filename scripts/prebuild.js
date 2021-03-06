const fs = require('fs')
const path = require('path')
const util = require('util')
const rimraf = require('rimraf')

const readdir = util.promisify(fs.readdir)
const readFile = util.promisify(fs.readFile)
const writeFile = util.promisify(fs.writeFile)

// Configs for paths to files and dirs
const CONNECT_CONTRACT = 'Connect.sol'
const CONTROLLER_CONTRACT = 'Controller.sol'
const CONNECT_MOCK_CONTRACT = 'ConnectMock.sol'
const GAMES_FOLDER = 'games'
const MOCKS_FOLDER = 'mocks'
const GENERATED_FOLDER = '.generated'

const readConnectTemplate = () => readFile(
  path.resolve(__dirname, '../contracts/', CONNECT_CONTRACT), 'utf8')

const readControllerTemplate = () => readFile(
  path.resolve(__dirname, '../contracts/', CONTROLLER_CONTRACT), 'utf8')

const readConnectMockTemplate = () => readFile(
  path.resolve(__dirname, '../contracts/', MOCKS_FOLDER, CONNECT_MOCK_CONTRACT), 'utf8')

const generateConnect = (connectTmpl, gameName) => {
  // XXX this is kind of nasty, maybe use proper placeholders?
  // Because connect is to be placed in .generated we must change path
  return connectTmpl.replace(
    `import { TTTGame as Game } from "./TTTGame.sol";`,
    `import { ${gameName} as Game } from "../${GAMES_FOLDER}/${gameName}.sol";`
  ).replace(
    'import "./random/IRandom.sol";',
    'import "../random/IRandom.sol";'
  ).replace(
    'library Connect',
    `library ${gameName}Connect`
  )
}

const generateController = (controllerTmpl, gameName) => {
  // Change the path as controller and connect will be both inside .generated
  return controllerTmpl.replace(
    'import "./Connect.sol";',
    `import { ${gameName}Connect as Connect } from "./${gameName}Connect.sol";`
  ).replace(
    'import "./util/BytesUtil.sol";',
    'import "../util/BytesUtil.sol";'
  ).replace(
    'import "./statechan/Fastforwardable.sol";',
    'import "../statechan/Fastforwardable.sol";'
  ).replace(
    'import "./random/SerializableRXRandom.sol";',
    'import "../random/SerializableRXRandom.sol";'
  ).replace(
    'import "./TTTGame.sol";',
    `import { ${gameName} as Game } from "../${GAMES_FOLDER}/${gameName}.sol";`
  ).replace(
    'contract Controller',
    `contract ${gameName}Controller`
  )
}

const generateConnectMock = (connectMockTmpl, gameName) => {
  return connectMockTmpl.replace(
    'import "../Connect.sol";',
    `import { ${gameName}Connect as Connect } from "./${gameName}Connect.sol";`
  ).replace(
    'import "../TTTGame.sol";',
    `import { ${gameName} as Game } from "../${GAMES_FOLDER}/${gameName}.sol";`
  ).replace(
    'contract ConnectMock',
    `contract ${gameName}ConnectMock`
  )
}

const prebuild = async () => {
  const generatedFolder = path.resolve(__dirname, '../contracts/', GENERATED_FOLDER)
  rimraf.sync(generatedFolder)
  if (!fs.existsSync(generatedFolder)) {
    fs.mkdirSync(generatedFolder)
  }
  // read templates
  const connectTempl = await readConnectTemplate()
  const controllerTmpl = await readControllerTemplate()
  const connectMockTmpl = await readConnectMockTemplate()
  const fnames = await readdir(path.resolve(__dirname, '../contracts/', GAMES_FOLDER))
  fnames.filter((fname) => path.extname(fname) === '.sol').forEach(async (fname) => {
    console.log(`Prebuilding game: ${fname}...`)
    // get the game name
    const gameName = path.basename(fname, '.sol')
    await writeFile(path.resolve(generatedFolder, `${gameName}Connect.sol`),
      generateConnect(connectTempl, gameName))
    await writeFile(path.resolve(generatedFolder, `${gameName}Controller.sol`),
      generateController(controllerTmpl, gameName))
    await writeFile(path.resolve(generatedFolder, `${gameName}ConnectMock.sol`),
      generateConnectMock(connectMockTmpl, gameName))
    console.log(`Prebuild game done: ${fname}`)
  })
}

prebuild()
