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
const GAMES_FOLDER = 'games'
const GENERATED_FOLDER = '.generated'

const readConnectTemplate = () => readFile(
  path.resolve(__dirname, '../contracts/', CONNECT_CONTRACT), 'utf8')

const readControllerTemplate = () => readFile(
  path.resolve(__dirname, '../contracts/', CONTROLLER_CONTRACT), 'utf8')

const generateConnect = (connectTmpl, gameName) => {
  // XXX this is kind of nasty, maybe use proper placeholders?
  // Because connect is to be placed in .generated we must change path
  return connectTmpl.replace(
    `import { TTTGame as Game } from "./TTTGame.sol";`,
    `import { ${gameName} as Game } from "../${GAMES_FOLDER}/${gameName}.sol";`
  ).replace(
    'import "./random/RXRandom.sol";',
    'import "../random/RXRandom.sol";'
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
    'import "./random/RXRandom.sol";',
    'import "../random/RXRandom.sol";'
  ).replace(
    'import "./TTTGame.sol";',
    `import { ${gameName} as Game } from "../${GAMES_FOLDER}/${gameName}.sol";`
  ).replace(
    'contract Controller',
    `contract ${gameName}Controller`
  )
}

const prebuild = async () => {
  const generatedFolder = path.resolve(__dirname, '../contracts/', GENERATED_FOLDER)
  rimraf.sync(generatedFolder)
  if (!fs.existsSync(generatedFolder)) {
    fs.mkdirSync(generatedFolder)
  }
  const connectTempl = await readConnectTemplate()
  const controllerTmpl = await readControllerTemplate()
  const fnames = await readdir(path.resolve(__dirname, '../contracts/', GAMES_FOLDER))
  fnames.filter((fname) => path.extname(fname) === '.sol').forEach(async (fname) => {
    console.log(`Prebuilding game: ${fname}...`)
    // get the game name
    const gameName = path.basename(fname, '.sol')
    const gameConnect = generateConnect(connectTempl, gameName)
    const gameController = generateController(controllerTmpl, gameName)
    await writeFile(path.resolve(generatedFolder, `${gameName}Connect.sol`), gameConnect)
    await writeFile(path.resolve(generatedFolder, `${gameName}Controller.sol`), gameController)
    console.log(`Prebuild game done: ${fname}`)
  })
}

prebuild()
