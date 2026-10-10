const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const outDir = path.join(root, "www");

const entriesToCopy = [
  "index.html",
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

function copyEntry(entry) {
  const source = path.join(root, entry);
  const target = path.join(outDir, entry);

  if (!fs.existsSync(source)) {
    throw new Error(`Missing required app file: ${entry}`);
  }

  fs.cpSync(source, target, { recursive: true });
}

removeDir(outDir);
fs.mkdirSync(outDir, { recursive: true });
entriesToCopy.forEach(copyEntry);

console.log(`Prepared Capacitor web bundle in ${outDir}`);
