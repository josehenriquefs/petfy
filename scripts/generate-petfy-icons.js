#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const iconDir = path.join(
  repoRoot,
  "app",
  "macos",
  "Runner",
  "Assets.xcassets",
  "AppIcon.appiconset"
);

const icons = [
  ["app_icon_16.png", 16],
  ["app_icon_32.png", 32],
  ["app_icon_64.png", 64],
  ["app_icon_128.png", 128],
  ["app_icon_256.png", 256],
  ["app_icon_512.png", 512],
  ["app_icon_1024.png", 1024]
];

fs.mkdirSync(iconDir, { recursive: true });
for (const [fileName, size] of icons) {
  fs.writeFileSync(path.join(iconDir, fileName), renderIcon(size));
}

console.log(`Generated ${icons.length} Petfy app icons in ${iconDir}`);

function renderIcon(size) {
  const image = new Uint8ClampedArray(size * size * 4);

  roundedRect(image, size, 0, 0, size, size, size * 0.22, [13, 83, 80, 255]);
  roundedRect(
    image,
    size,
    size * 0.065,
    size * 0.065,
    size * 0.87,
    size * 0.87,
    size * 0.20,
    [22, 163, 148, 255]
  );

  ellipse(image, size, size * 0.50, size * 0.54, size * 0.35, size * 0.38, [246, 226, 195, 255]);
  ellipse(image, size, size * 0.30, size * 0.39, size * 0.15, size * 0.22, [83, 55, 43, 255]);
  ellipse(image, size, size * 0.70, size * 0.39, size * 0.15, size * 0.22, [83, 55, 43, 255]);
  ellipse(image, size, size * 0.50, size * 0.60, size * 0.24, size * 0.20, [128, 86, 61, 255]);
  ellipse(image, size, size * 0.50, size * 0.66, size * 0.23, size * 0.15, [255, 241, 219, 255]);
  ellipse(image, size, size * 0.39, size * 0.48, size * 0.055, size * 0.070, [28, 31, 35, 255]);
  ellipse(image, size, size * 0.61, size * 0.48, size * 0.055, size * 0.070, [28, 31, 35, 255]);
  ellipse(image, size, size * 0.41, size * 0.46, size * 0.016, size * 0.020, [255, 255, 255, 220]);
  ellipse(image, size, size * 0.63, size * 0.46, size * 0.016, size * 0.020, [255, 255, 255, 220]);
  ellipse(image, size, size * 0.50, size * 0.58, size * 0.060, size * 0.040, [24, 25, 28, 255]);
  ellipse(image, size, size * 0.50, size * 0.725, size * 0.105, size * 0.030, [24, 25, 28, 255]);

  return encodePng(size, size, image);
}

function roundedRect(image, size, x, y, width, height, radius, color) {
  const minX = Math.floor(x);
  const maxX = Math.ceil(x + width);
  const minY = Math.floor(y);
  const maxY = Math.ceil(y + height);

  for (let py = minY; py < maxY; py += 1) {
    for (let px = minX; px < maxX; px += 1) {
      const cx = Math.max(x + radius, Math.min(px + 0.5, x + width - radius));
      const cy = Math.max(y + radius, Math.min(py + 0.5, y + height - radius));
      const distance = Math.hypot(px + 0.5 - cx, py + 0.5 - cy);
      const alpha = clamp(radius + 0.5 - distance, 0, 1);
      if (alpha > 0) {
        blend(image, size, px, py, color, alpha);
      }
    }
  }
}

function ellipse(image, size, cx, cy, rx, ry, color) {
  const minX = Math.max(0, Math.floor(cx - rx - 1));
  const maxX = Math.min(size, Math.ceil(cx + rx + 1));
  const minY = Math.max(0, Math.floor(cy - ry - 1));
  const maxY = Math.min(size, Math.ceil(cy + ry + 1));

  for (let y = minY; y < maxY; y += 1) {
    for (let x = minX; x < maxX; x += 1) {
      const dx = (x + 0.5 - cx) / rx;
      const dy = (y + 0.5 - cy) / ry;
      const distance = Math.sqrt(dx * dx + dy * dy);
      const alpha = clamp((1 - distance) * Math.min(rx, ry), 0, 1);
      if (alpha > 0) {
        blend(image, size, x, y, color, alpha);
      }
    }
  }
}

function blend(image, size, x, y, color, coverage) {
  if (x < 0 || x >= size || y < 0 || y >= size) {
    return;
  }

  const offset = (y * size + x) * 4;
  const sourceAlpha = (color[3] / 255) * coverage;
  const targetAlpha = image[offset + 3] / 255;
  const outAlpha = sourceAlpha + targetAlpha * (1 - sourceAlpha);
  if (outAlpha <= 0) {
    return;
  }

  for (let channel = 0; channel < 3; channel += 1) {
    image[offset + channel] = Math.round(
      (color[channel] * sourceAlpha + image[offset + channel] * targetAlpha * (1 - sourceAlpha)) /
        outAlpha
    );
  }
  image[offset + 3] = Math.round(outAlpha * 255);
}

function encodePng(width, height, rgba) {
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y += 1) {
    raw[y * (stride + 1)] = 0;
    Buffer.from(rgba.buffer, y * stride, stride).copy(raw, y * (stride + 1) + 1);
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr(width, height)),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0))
  ]);
}

function ihdr(width, height) {
  const buffer = Buffer.alloc(13);
  buffer.writeUInt32BE(width, 0);
  buffer.writeUInt32BE(height, 4);
  buffer[8] = 8;
  buffer[9] = 6;
  buffer[10] = 0;
  buffer[11] = 0;
  buffer[12] = 0;
  return buffer;
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])), 0);
  return Buffer.concat([length, typeBuffer, data, crc]);
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = crc & 1 ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
