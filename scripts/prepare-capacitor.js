const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "www");

const entriesToCopy = [
  "index.html",
  "delete-account.html",
  "privacy-policy.html",
  "dairy-app.css",
  "script.js",
  "product-images.js",
  "Supabase.js",
  "manifest.json",
  "sw.js",
  "images"
];

function removeDir(target) {
  fs.rmSync(target, { recursive: true, force: true });
}

function shouldCopyPath(sourcePath) {
  const base = path.basename(sourcePath);
  if (base === ".DS_Store") return false;
  const rel = path.relative(root, sourcePath).replace(/\\/g, "/");
  if (rel === "images/backgrounds" || rel.startsWith("images/backgrounds/")) {
    return false;
  }
  return true;
}

function copyEntry(entry) {
  const source = path.join(root, entry);
  const target = path.join(outDir, entry);

  if (!fs.existsSync(source)) {
    throw new Error(`Missing required app file: ${entry}`);
  }

  fs.cpSync(source, target, { recursive: true, filter: shouldCopyPath });
}

removeDir(outDir);
fs.mkdirSync(outDir, { recursive: true });
entriesToCopy.forEach(copyEntry);

console.log(`Prepared Capacitor web bundle in ${outDir}`);
