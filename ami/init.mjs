import fs from "fs"
import { spawn } from "child_process"
import path from "path"

const CONFIG_DIR = "/home/node/.openclaw"
const CONFIG_FILE = path.join(CONFIG_DIR, "openclaw.json")
const TEMPLATE_FILE = path.join(CONFIG_DIR, "openclaw.json.tmpl")

function renderTemplate(template) {
  return template.replace(/\$\{([^}]+)\}/g, (_, name) => {
    return process.env[name] ?? ""
  })
}

async function ensureConfig() {
  try {
    await fs.promises.access(CONFIG_FILE)
    console.log("openclaw.json already exists, skipping template hydration")
    return
  } catch {}

  try {
    const tmpl = await fs.promises.readFile(TEMPLATE_FILE, "utf8")

    console.log("Generating openclaw.json from template")

    const rendered = renderTemplate(tmpl)

    await fs.promises.mkdir(CONFIG_DIR, { recursive: true })
    await fs.promises.writeFile(CONFIG_FILE, rendered, { mode: 0o600 })
  } catch (err) {
    console.error("Failed to generate config:", err)
    process.exit(1)
  }
}

function startGateway() {
  const child = spawn("node", ["openclaw.mjs", "gateway", "--bind", "lan"], {
    stdio: "inherit",
    env: process.env,
  })

  // Forward signals for clean shutdown
  process.on("SIGINT", () => child.kill("SIGINT"))
  process.on("SIGTERM", () => child.kill("SIGTERM"))

  child.on("exit", code => {
    process.exit(code)
  })
}

await ensureConfig()
startGateway()
