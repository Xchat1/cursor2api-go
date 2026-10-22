'use strict';
const [major, minor, patch] = process.versions.node.split('.').map(Number);
const minimum = {22: [23, 4], 24: [22, 1], 26: [12, 1]}[major];
if (!minimum || minor < minimum[0] || (minor === minimum[0] && patch < minimum[1])) {
  console.error('Use a patched Node.js release: 22.23.4+, 24.22.1+, or 26.12.1+ within these supported majors.');
  process.exit(1);
}
