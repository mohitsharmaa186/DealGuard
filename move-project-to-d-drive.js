const fs = require('fs');
const path = require('path');

const source = process.cwd();
const destination = 'D:\\Deal Gaurd\\DealGaurd';
const accidentalFolder = path.join(source, 'Gaurd');

function normalize(value) {
  return path.resolve(value).toLowerCase();
}

function isEmptyDirectory(dirPath) {
  if (!fs.existsSync(dirPath)) return true;
  const entries = fs.readdirSync(dirPath);
  return entries.every((entry) => {
    const child = path.join(dirPath, entry);
    return fs.statSync(child).isDirectory() && isEmptyDirectory(child);
  });
}

const sourcePath = normalize(source);
const destinationPath = normalize(destination);

if (destinationPath === sourcePath || destinationPath.startsWith(`${sourcePath}${path.sep}`)) {
  throw new Error(`Refusing to move into a child of the source folder: ${destination}`);
}

fs.mkdirSync(destination, { recursive: true });

const moved = [];

for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
  if (entry.name === 'Gaurd' && isEmptyDirectory(accidentalFolder)) {
    fs.rmSync(accidentalFolder, { recursive: true, force: true });
    continue;
  }

  const from = path.join(source, entry.name);
  const to = path.join(destination, entry.name);

  fs.cpSync(from, to, { recursive: true, force: true, verbatimSymlinks: true });
  fs.rmSync(from, { recursive: true, force: true });
  moved.push(entry.name);
}

console.log(`Moved ${moved.length} top-level project entries to ${destination}`);
console.log(moved.join('\n'));
