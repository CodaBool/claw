import fs from "fs"
import path from "path"

const SRC = "/app/skills"
const DEST = "/home/node/.openclaw/workspace/skills"

async function main() {
  await fs.promises.mkdir(DEST, { recursive: true })

  const entries = await fs.promises.readdir(SRC, { withFileTypes: true })

  if (entries.length === 0) {
    console.log("no skills found")
    return
  }

  for (const entry of entries) {
    const src = path.join(SRC, entry.name)
    const dest = path.join(DEST, entry.name)

    await fs.promises.cp(src, dest, {
      recursive: true,
      force: true,
    })

    console.log(`installed skill: ${entry.name}`)
  }

  console.log("skill install complete")
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
