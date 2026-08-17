// Generates android/app/src/main/res/drawable-nodpi/splash_screen_icon.png:
// the wordmark centred on a large transparent canvas, for use as
// android:windowSplashScreenAnimatedIcon on Android 12+.
//
// Run with: node tool/generate_splash_icon.js
// One-time generation step - re-run only if splash_logo.png changes.
//
// WHY THE PADDING HAS TO BE BAKED INTO THE PIXELS
//
// Android 12+ replaced the old "windowBackground is the splash" behaviour with
// the system SplashScreen API, which renders windowSplashScreenAnimatedIcon
// under two rules that together defeat every XML-level sizing trick:
//
//   1. The drawable's INTRINSIC SIZE IS IGNORED. SplashscreenIconDrawableFactory
//      force-calls setBounds() on it twice (AdaptiveForegroundDrawable
//      .updateLayerBounds, then ImmobileIconDrawable.preDrawIcon), so a
//      <layer-list> declaring 120dp - or a transparent <shape><size/></shape>
//      spacer layer - is simply overruled and magnified to fill the slot.
//   2. The OUTER THIRD IS ALWAYS MASKED AWAY. Every code path for a supplied
//      icon wraps it in MaskBackgroundDrawable, which clips to
//      R.string.config_icon_mask. There is no opt-out, and the mask silhouette
//      is device-dependent (AOSP ships a rounded square; Pixel and several OEMs
//      substitute a circle), so only the inscribed circle is safe.
//
// The one technique that survives both is to make the artwork occupy a smaller
// FRACTION of its own canvas: because the drawable is stretched to whatever
// bounds it is given, that fraction is preserved exactly at any density, on any
// device, with or without an icon background colour. This is the same rule
// Google's own adaptive-icon spec states as "the inner two-thirds".
//
// SIZING
//
// Without windowSplashScreenIconBackgroundColor set, the icon canvas is 288dp
// and the visible masked region is the inner 192dp (2/3). Flutter's own loading
// screen (_LoadingScreen in lib/main.dart) draws this same 432px artwork at
// 120dp, so to make the OS splash and Flutter's first frame identical the
// artwork must cover 120/288 = 41.7% of the canvas:
//
//   canvas = 432 / (120 / 288) = 1036px
//
// which renders the logo at 432/1036 * 288 = 120.1dp, with the wordmark itself
// (~80% of that) about 96dp wide - comfortably inside the 192dp mask.

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SRC = path.join(__dirname, '..', 'android/app/src/main/res/drawable/splash_logo.png');
const OUT_DIR = path.join(__dirname, '..', 'android/app/src/main/res/drawable-nodpi');
const OUT = path.join(OUT_DIR, 'splash_screen_icon.png');

const CANVAS = 1036;

// --- minimal PNG decode (8-bit RGBA, non-interlaced only) ---------------------

function readChunks(buf) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (!buf.slice(0, 8).equals(sig)) throw new Error('not a PNG');
  const out = {};
  let o = 8;
  while (o < buf.length) {
    const len = buf.readUInt32BE(o);
    const type = buf.toString('ascii', o + 4, o + 8);
    (out[type] = out[type] || []).push(buf.slice(o + 8, o + 8 + len));
    o += 12 + len;
  }
  return out;
}

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

function decodeRgba(buf) {
  const chunks = readChunks(buf);
  const ihdr = chunks.IHDR[0];
  const width = ihdr.readUInt32BE(0);
  const height = ihdr.readUInt32BE(4);
  const bitDepth = ihdr[8];
  const colorType = ihdr[9];
  const interlace = ihdr[12];
  if (bitDepth !== 8 || colorType !== 6 || interlace !== 0) {
    throw new Error(`unsupported PNG: bitDepth=${bitDepth} colorType=${colorType} interlace=${interlace} (expected 8/6/0)`);
  }

  const bpp = 4;
  const stride = width * bpp;
  const raw = zlib.inflateSync(Buffer.concat(chunks.IDAT));
  const px = Buffer.alloc(height * stride);

  let ro = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[ro++];
    const line = raw.slice(ro, ro + stride);
    ro += stride;
    const cur = px.slice(y * stride, (y + 1) * stride);
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? cur[x - bpp] : 0;
      const b = y > 0 ? px[(y - 1) * stride + x] : 0;
      const c = x >= bpp && y > 0 ? px[(y - 1) * stride + x - bpp] : 0;
      let v = line[x];
      if (filter === 1) v += a;
      else if (filter === 2) v += b;
      else if (filter === 3) v += (a + b) >> 1;
      else if (filter === 4) v += paeth(a, b, c);
      else if (filter !== 0) throw new Error('bad filter ' + filter);
      cur[x] = v & 0xff;
    }
  }
  return { width, height, px };
}

// --- minimal PNG encode (8-bit RGBA, filter type 0) ---------------------------

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}

function encodeRgba(width, height, px) {
  const stride = width * 4;
  const rawWithFilters = Buffer.alloc(height * (stride + 1));
  for (let y = 0; y < height; y++) {
    rawWithFilters[y * (stride + 1)] = 0; // filter: None
    px.copy(rawWithFilters, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // colour type: RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(rawWithFilters, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// --- generate -----------------------------------------------------------------

const src = decodeRgba(fs.readFileSync(SRC));
if (src.width !== src.height) throw new Error('expected a square source image');
if (src.width > CANVAS) throw new Error(`source ${src.width}px does not fit in a ${CANVAS}px canvas`);

// Guard the assumption the whole approach rests on: the padding is transparent,
// so a source with an opaque background would paint a visible square onto the
// splash instead of blending into it.
const corner = src.px.readUInt32BE(0);
if ((corner & 0xff) !== 0) {
  throw new Error(`source corner pixel is opaque (alpha=${corner & 0xff}); the artwork must have a transparent background`);
}

const offset = Math.floor((CANVAS - src.width) / 2);
const out = Buffer.alloc(CANVAS * CANVAS * 4); // zero-filled == fully transparent
for (let y = 0; y < src.height; y++) {
  src.px.copy(out, ((y + offset) * CANVAS + offset) * 4, y * src.width * 4, (y + 1) * src.width * 4);
}

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(OUT, encodeRgba(CANVAS, CANVAS, out));

const pct = ((src.width / CANVAS) * 100).toFixed(1);
console.log(`wrote ${path.relative(path.join(__dirname, '..'), OUT)}`);
console.log(`  ${src.width}px artwork centred on a ${CANVAS}px transparent canvas (${pct}% coverage)`);
console.log(`  renders at ${((src.width / CANVAS) * 288).toFixed(1)}dp inside the 288dp splash icon canvas`);
console.log(`  visible mask region is 192dp, so it is never cropped`);
