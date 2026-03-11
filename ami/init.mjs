import fs from "fs"
import { spawn } from "child_process"
import path from "path"

const CONFIG_DIR = "/home/node/.openclaw"
const CONFIG_FILE = path.join(CONFIG_DIR, "openclaw.json")
const TEMPLATE_FILE = path.join("/app", "openclaw.json.tmpl")
const AUTH_PROFILES_TEMPLATE_FILE = path.join("/app", "auth-profiles.json.tmpl")

const AUTH_PROFILES_FILE = path.join(
  CONFIG_DIR,
  "agents",
  "main",
  "agent",
  "auth-profiles.json"
)

const BREW_PREFIX = "/home/node/.linuxbrew"
const BREW_BIN = path.join(BREW_PREFIX, "bin", "brew")

const BREW_PACKAGES = ["gh"]

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      stdio: "inherit",
      env: process.env,
    })

    child.on("error", reject)
    child.on("exit", code => {
      if (code === 0) resolve()
      else reject(new Error(`${cmd} ${args.join(" ")} exited with code ${code}`))
    })
  })
}

function runCapture(cmd, args) {
  return new Promise((resolve, reject) => {
    let stdout = ""
    let stderr = ""

    const child = spawn(cmd, args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    })

    child.stdout.on("data", c => (stdout += c))
    child.stderr.on("data", c => (stderr += c))

    child.on("error", reject)
    child.on("exit", code => {
      if (code === 0) resolve(stdout.toString())
      else reject(new Error(stderr || stdout))
    })
  })
}

function renderTemplate(template) {
  return template.replace(/\$\{([^}]+)\}/g, (_, name) => {
    return process.env[name] ?? ""
  })
}

async function ensureBrew() {
  try {
    await fs.promises.access(BREW_BIN)
    console.log("brew already installed")
  } catch {
    console.log("installing brew")
    await fs.promises.mkdir(BREW_PREFIX, { recursive: true })
    await run("git", ["clone", "https://github.com/Homebrew/brew", BREW_PREFIX])
  }

  process.env.PATH =
    `${BREW_PREFIX}/bin:${BREW_PREFIX}/sbin:` + (process.env.PATH || "")

  await run(BREW_BIN, ["update", "--force", "--quiet"])
}

async function ensureBrewPackages() {
  for (const pkg of BREW_PACKAGES) {
    try {
      await runCapture(BREW_BIN, ["list", "--versions", pkg])
      console.log(`brew package already installed: ${pkg}`)
    } catch {
      console.log(`installing brew package: ${pkg}`)
      await run(BREW_BIN, ["install", pkg])
    }
  }
}

async function hydrateTemplate(templateFile, outputFile) {
  try {
    await fs.promises.access(outputFile)
    return
  } catch {}

  const tmpl = await fs.promises.readFile(templateFile, "utf8")
  const rendered = renderTemplate(tmpl)

  await fs.promises.mkdir(path.dirname(outputFile), { recursive: true })
  await fs.promises.writeFile(outputFile, rendered, { mode: 0o600 })
}

async function ensureConfig() {
  await hydrateTemplate(TEMPLATE_FILE, CONFIG_FILE)
  await hydrateTemplate(AUTH_PROFILES_TEMPLATE_FILE, AUTH_PROFILES_FILE)
}

function startGateway() {
  const child = spawn("node", ["openclaw.mjs", "gateway", "--bind", "lan"], {
    stdio: "inherit",
    env: process.env,
  })

  process.on("SIGINT", () => child.kill("SIGINT"))
  process.on("SIGTERM", () => child.kill("SIGTERM"))

  child.on("exit", code => process.exit(code))
}

await ensureBrew()
await ensureBrewPackages()
await ensureConfig()
startGateway()
