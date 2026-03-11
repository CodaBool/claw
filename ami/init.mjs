import fs from "fs"
import { spawn } from "child_process"
import path from "path"

const CONFIG_DIR = "/home/node/.openclaw"

const CONFIG_FILE = path.join(CONFIG_DIR, "openclaw.json")
const TEMPLATE_FILE = path.join(CONFIG_DIR, "openclaw.json.tmpl")

const AUTH_PROFILES_FILE = path.join(
  CONFIG_DIR,
  "agents",
  "main",
  "agent",
  "auth-profiles.json"
)
const AUTH_PROFILES_TEMPLATE_FILE = path.join(
  CONFIG_DIR,
  "auth-profiles.json.tmpl"
)

const SKILLS_SOURCE_DIR = "/app/skills"
const WORKSPACES_DIR = path.join(CONFIG_DIR, "workspaces")
const WORKSPACE_SKILLS_DIR = path.join(WORKSPACES_DIR, "skills")

const BREW_PREFIX = "/home/node/.linuxbrew"
const BREW_REPO = BREW_PREFIX
const BREW_BIN = path.join(BREW_PREFIX, "bin", "brew")
const BREW_CELLAR = path.join(BREW_PREFIX, "Cellar")

const BREW_PACKAGES = ["gh"]

function renderTemplate(template) {
  return template.replace(/\$\{([^}]+)\}/g, (_, name) => {
    return process.env[name] ?? ""
  })
}

function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      stdio: "inherit",
      env: opts.env ?? process.env,
      cwd: opts.cwd ?? process.cwd(),
    })

    child.on("error", reject)
    child.on("exit", code => {
      if (code === 0) resolve()
      else reject(new Error(`${cmd} ${args.join(" ")} exited with code ${code}`))
    })
  })
}

function runCapture(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    let stdout = ""
    let stderr = ""

    const child = spawn(cmd, args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: opts.env ?? process.env,
      cwd: opts.cwd ?? process.cwd(),
    })

    child.stdout.on("data", chunk => {
      stdout += chunk.toString()
    })

    child.stderr.on("data", chunk => {
      stderr += chunk.toString()
    })

    child.on("error", reject)
    child.on("exit", code => {
      if (code === 0) resolve({ stdout, stderr })
      else {
        reject(
          new Error(
            `${cmd} ${args.join(" ")} exited with code ${code}\n${stderr || stdout}`
          )
        )
      }
    })
  })
}

async function pathExists(target) {
  try {
    await fs.promises.access(target)
    return true
  } catch {
    return false
  }
}

async function ensureBrew() {
  try {
    await fs.promises.access(BREW_BIN)
    console.log(`brew already exists at ${BREW_BIN}`)
  } catch {
    console.log(`brew not found, installing into unsupported prefix: ${BREW_PREFIX}`)
    await fs.promises.mkdir(BREW_PREFIX, { recursive: true })
    await run("git", ["clone", "https://github.com/Homebrew/brew", BREW_PREFIX])
  }

  process.env.HOMEBREW_PREFIX = BREW_PREFIX
  process.env.HOMEBREW_CELLAR = BREW_CELLAR
  process.env.HOMEBREW_REPOSITORY = BREW_REPO
  process.env.PATH = [
    path.join(BREW_PREFIX, "bin"),
    path.join(BREW_PREFIX, "sbin"),
    process.env.PATH || "",
  ].join(":")

  await run(BREW_BIN, ["update", "--force", "--quiet"])

  const zshShare = path.join(BREW_PREFIX, "share", "zsh")
  try {
    await fs.promises.access(zshShare)
    await run("chmod", ["-R", "go-w", zshShare])
  } catch {
    // ignore if zsh dir doesn't exist yet
  }

  await run(BREW_BIN, ["--version"])
}

async function isBrewPackageInstalled(pkg) {
  try {
    await runCapture(BREW_BIN, ["list", "--versions", pkg])
    return true
  } catch {
    return false
  }
}

async function ensureBrewPackages(packages) {
  for (const pkg of packages) {
    if (await isBrewPackageInstalled(pkg)) {
      console.log(`brew package already installed: ${pkg}`)
      continue
    }

    console.log(`installing brew package: ${pkg}`)
    await run(BREW_BIN, ["install", pkg])
  }
}

async function hydrateTemplate({
  templateFile,
  outputFile,
  label,
  mode = 0o600,
}) {
  try {
    await fs.promises.access(outputFile)
    console.log(`${label} already exists, skipping template hydration`)
    return
  } catch {
    // target does not exist, continue
  }

  try {
    const tmpl = await fs.promises.readFile(templateFile, "utf8")
    const rendered = renderTemplate(tmpl)

    await fs.promises.mkdir(path.dirname(outputFile), { recursive: true })
    await fs.promises.writeFile(outputFile, rendered, { mode })

    console.log(`Generated ${label} from template`)
  } catch (err) {
    console.error(`Failed to generate ${label}:`, err)
    process.exit(1)
  }
}

async function ensureConfig() {
  await hydrateTemplate({
    templateFile: TEMPLATE_FILE,
    outputFile: CONFIG_FILE,
    label: "openclaw.json",
  })

  await hydrateTemplate({
    templateFile: AUTH_PROFILES_TEMPLATE_FILE,
    outputFile: AUTH_PROFILES_FILE,
    label: "auth-profiles.json",
  })
}

async function copyCheckedInSkills() {
  const hasSourceSkills = await pathExists(SKILLS_SOURCE_DIR)
  if (!hasSourceSkills) {
    console.log(`No checked-in skills directory found at ${SKILLS_SOURCE_DIR}, skipping`)
    return
  }

  await fs.promises.mkdir(WORKSPACE_SKILLS_DIR, { recursive: true })

  const entries = await fs.promises.readdir(SKILLS_SOURCE_DIR, { withFileTypes: true })
  if (entries.length === 0) {
    console.log(`No skills found in ${SKILLS_SOURCE_DIR}, skipping`)
    return
  }

  for (const entry of entries) {
    const src = path.join(SKILLS_SOURCE_DIR, entry.name)
    const dest = path.join(WORKSPACE_SKILLS_DIR, entry.name)

    await fs.promises.cp(src, dest, {
      recursive: true,
      force: true,
    })

    console.log(`Copied skill asset: ${entry.name}`)
  }
}

function startGateway() {
  const child = spawn("node", ["openclaw.mjs", "gateway", "--bind", "lan"], {
    stdio: "inherit",
    env: process.env,
  })

  process.on("SIGINT", () => child.kill("SIGINT"))
  process.on("SIGTERM", () => child.kill("SIGTERM"))

  child.on("exit", code => {
    process.exit(code)
  })
}

await ensureBrew()
await ensureBrewPackages(BREW_PACKAGES)
await ensureConfig()
await copyCheckedInSkills()
startGateway()
