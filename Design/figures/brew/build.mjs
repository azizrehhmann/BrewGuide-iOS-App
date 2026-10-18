// Brew figure: a coffee scale with a glass server and a V60 on top.
// Static art is split into a back layer (behind the water) and a front layer (glass front, handle, dripper),
// so the app and the canvas can draw the live water, the LCD reading and the drip between them.
//   node build.mjs            -> out/brew-{back,front,full}-{light,dark}.svg, out/brew-geometry.json, out/brew-check-*.html
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "../kit/iso-kit.mjs";
import * as G from "../kit/lathe.mjs";
import { kohi } from "../kohi.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "out");
mkdirSync(OUT, { recursive: true });

const WIDTH = 340;
const HEIGHT = 360;

// Scale
const BODY = { x: -84, y: -66, w: 168, d: 132, r: 14 };
const BODY_H = 15;
const FOOT_H = 5;
const PAN = { x: -74, y: -62, w: 148, d: 96, r: 10 };
const PAN_TOP = BODY_H + 3;
const LCD = { x: -40, y: 40, w: 80, d: 18, r: 3 };
const BUTTONS = [[-58, 49], [58, 49]];

// Server (glass) on the pan, V60 on the server
const C = [0, -14];
const GLASS_R = 34;
const GLASS_IN = 31.5;
const GLASS_Z0 = PAN_TOP;
const GLASS_TOP = GLASS_Z0 + 74.5;
const WATER_Z0 = GLASS_Z0 + 3.5;
const WATER_MAX = 78;
const CONE_TIP = 84;
const CONE_TOP = 130;
const FLANGE_Z = GLASS_TOP;
const FLANGE_R = 42;

const P = k.fitProjection(
  [...k.boxCorners(BODY, -FOOT_H, PAN_TOP), [C[0] - 40, C[1] - 40, CONE_TOP], [C[0] + 40, C[1] + 40, CONE_TOP], [C[0] + 52, C[1], 80]],
  WIDTH,
  HEIGHT,
  { pad: 14, azimuth: 45, elevation: 30 },
);
const at = (point) => k.iso(point, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (points, style) => k.dotsSvg(points, style);
const path = (points) => k.pathOf(points.map(at));
const byDepth = (points) => [...points].sort((a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P));
const onCylinder = (r, angle, z) => [C[0] + r * Math.cos(angle), C[1] + r * Math.sin(angle), z];

function scale() {
  const out = [`<path class="iso-halo" d="${k.haloOf(BODY, -FOOT_H, BODY_H, P)}"/>`];
  for (const [x, y] of byDepth(k.corners(BODY, 18))) {
    out.push(S(k.cylinder(x, y, 7, -FOOT_H, 1.4, P, 28), { tone: "lo" }));
    out.push(S(k.cylinder(x, y, 5.6, -FOOT_H + 1.4, FOOT_H - 1.4, P, 28), { tone: "lo" }));
  }
  // Case with a trim band, a lower lip and the platform on top
  out.push(S(k.slabOf(BODY, 0, BODY_H, P, 10, 1.2), { tone: "mid", inner: L(k.sideSeam(BODY, 5, P, 10), { tone: "faint" }) }));
  out.push(L(k.planOutline(k.insetPlan(BODY, 4), BODY_H, P, 10), { tone: "faint" }));
  out.push(S(k.slabOf(PAN, BODY_H, PAN_TOP - BODY_H, P, 8, 0.8), { tone: "hi", crease: "lo" }));
  out.push(L(k.planOutline(k.insetPlan(PAN, 6), PAN_TOP, P, 8), { tone: "faint" }));
  // Rubber ring where the server stands
  out.push(L(k.ring(C[0], C[1], GLASS_R + 3, PAN_TOP, P, 64), { tone: "faint" }));
  // LCD bezel, window and the two buttons
  out.push(S(k.slabOf(LCD, BODY_H, 0.8, P, 3), { tone: "lo", crease: "none" }));
  out.push(`<path class="k-lcd" d="${k.pathOf(k.roundedPlan(k.insetPlan(LCD, 2.2), 3).map(([x, y]) => at([x, y, BODY_H + 0.8])), true)}"/>`);
  for (const [x, y] of BUTTONS) {
    out.push(S(k.cylinder(x, y, 4.6, BODY_H, 1.6, P, 28, 0.4), { tone: "mid" }));
    out.push(L(k.ring(x, y, 2.6, BODY_H + 1.6, P, 24), { tone: "lo" }));
  }
  out.push(D(BUTTONS.map(([x, y]) => at([x, y, BODY_H + 1.6])), { size: 0.45, tone: "mid" }));
  // Power and tare marks next to the buttons, the scale's one engraved label
  out.push(k.faceTextSvg(k.topMatrix([BUTTONS[1][0] - 2.6, BUTTONS[1][1] + 9], BODY_H, P, "x"), "TARE", { size: 3, tone: "lo" }));
  return out.join("");
}

function glassBack() {
  const out = [];
  // Thick glass base, then the body as a pale tint and the back of the rim
  const base = k.cylinder(C[0], C[1], GLASS_R, GLASS_Z0, 3.5, P, 72);
  out.push(`<path class="k-glass" d="${base.fill}"/>`);
  out.push(L(k.sideArc(C[0], C[1], GLASS_R, GLASS_Z0 + 3.5, P, 48), { tone: "faint" }));
  const body = k.cylinder(C[0], C[1], GLASS_R, GLASS_Z0, GLASS_TOP - GLASS_Z0, P, 72);
  out.push(`<path class="k-glass" d="${body.fill}"/>`);
  out.push(L(k.ring(C[0], C[1], GLASS_IN, GLASS_Z0 + 3.5, P, 72), { tone: "faint" }));
  out.push(L(k.ring(C[0], C[1], GLASS_R, GLASS_TOP, P, 72), { tone: "lo" }));
  out.push(L(k.ring(C[0], C[1], GLASS_IN, GLASS_TOP, P, 72), { tone: "faint" }));
  return out.join("");
}

function glassFront() {
  const out = [];
  const body = k.cylinder(C[0], C[1], GLASS_R, GLASS_Z0, GLASS_TOP - GLASS_Z0, P, 72);
  out.push(L(body.outline, { tone: "mid" }));
  out.push(L(k.sideArc(C[0], C[1], GLASS_R, GLASS_TOP, P, 48), { tone: "mid" }));
  // Graduations every 50 ml, a longer mark every 100 ml, printed on the side facing the viewer
  const face = (25 * Math.PI) / 180;
  const minor = [];
  const major = [];
  for (let i = 0, z = 30; z <= 84; i++, z += 6) {
    const span = i % 2 ? 0.1 : 0.2;
    (i % 2 ? minor : major).push(path([onCylinder(GLASS_R + 0.2, face, z), onCylinder(GLASS_R + 0.2, face + span, z)]));
  }
  out.push(L(minor.join(""), { tone: "lo", free: true }), L(major.join(""), { tone: "mid", free: true }));
  // Glass handle on the right: two stubs and a grip
  for (const z of [36, 74]) out.push(S(k.slabOf({ x: C[0] + GLASS_R - 2, y: C[1] - 3, w: 16, d: 6, r: 2 }, z, 5, P, 3, 0.4), { tone: "mid" }));
  out.push(S(k.slabOf({ x: C[0] + GLASS_R + 10, y: C[1] - 3.5, w: 6.5, d: 7, r: 2.5 }, 36, 43, P, 4, 0.5), { tone: "mid" }));
  return out.join("");
}

function dripper() {
  const out = [];
  const F = G.frameAlong([C[0], C[1], CONE_TIP], [0, 0, 1]);
  const flangeF = G.frameAlong([C[0], C[1], FLANGE_Z], [0, 0, 1]);
  // The cone's tip sits inside the server's mouth, the flange on its rim
  out.push(S(G.solidOf([[0, 4.6], [2.5, 6.2], [FLANGE_Z - CONE_TIP, 11]], F, P), { tone: "mid" }));
  out.push(S(G.disc(0, 2.6, FLANGE_R, flangeF, P), { tone: "mid" }));
  out.push(S(k.slabOf({ x: C[0] + FLANGE_R - 6, y: C[1] - 7, w: 20, d: 14, r: 5 }, FLANGE_Z, 2.6, P, 6, 0.4), { tone: "mid" }));
  out.push(L(k.ring(C[0] + FLANGE_R + 8, C[1], 2.4, FLANGE_Z + 2.6, P, 20), { tone: "lo" }));
  const s0 = FLANGE_Z + 2.6 - CONE_TIP;
  const s1 = CONE_TOP - CONE_TIP;
  const cone = [[s0, 11], [s1 - 2, 37.5], [s1, 38.5]];
  out.push(S(G.solidOf(cone, F, P), { tone: "hi", crease: "lo", inner: L(G.arcOf(F, s1 - 2, 37.5, P), { tone: "faint" }) }));
  // Grounds in the filter: a bed below the rim, with the paper filter's edge above it
  const bedZ = CONE_TOP - 9;
  out.push(`<path class="k-bed" d="${k.pathOf(k.circleRing(C[0], C[1], 30, 64).map(([x, y]) => at([x, y, bedZ])), true)}"/>`);
  out.push(L(k.ring(C[0], C[1], 36.4, CONE_TOP, P, 72), { tone: "lo" }));
  out.push(L(k.ring(C[0], C[1], 30, bedZ, P, 64), { tone: "lo" }));
  return out.join("");
}

// Live parts: water as a cylinder from WATER_Z0, drawn from projected circle offsets so the app can rebuild it
const ring = k.circleRing(0, 0, GLASS_IN - 0.3, 72);
const origin = at([C[0], C[1], WATER_Z0]);
const offsets = ring.map(([x, y]) => {
  const p = at([C[0] + x, C[1] + y, WATER_Z0]);
  return [+(p[0] - origin[0]).toFixed(2), +(p[1] - origin[1]).toFixed(2)];
});
const geometry = {
  viewBox: [WIDTH, HEIGHT],
  waterOrigin: origin.map((v) => +v.toFixed(2)),
  waterOffsets: offsets,
  risePerUnit: +k.screenRise(1, P).toFixed(4),
  waterMaxHeight: WATER_MAX - WATER_Z0,
  dripFrom: at([C[0], C[1], CONE_TIP]).map((v) => +v.toFixed(2)),
  lcdMatrix: k.topMatrix([LCD.x + 5, LCD.y + 12.6], BODY_H + 0.8, P, "x"),
  lcdTextSize: 8.4,
};

// The water shape for a fill fraction: the hull of the bottom and top ellipses
function waterPath(fraction) {
  const h = geometry.waterMaxHeight * fraction * geometry.risePerUnit;
  const xs = offsets.map(([x]) => x);
  const left = xs.indexOf(Math.min(...xs));
  const right = xs.indexOf(Math.max(...xs));
  const pts = offsets.map(([x, y], i) => {
    const lineY = offsets[left][1] + ((offsets[right][1] - offsets[left][1]) * (x - offsets[left][0])) / (offsets[right][0] - offsets[left][0]);
    const lift = y < lineY ? h : 0;
    return [origin[0] + x, origin[1] + y - lift];
  });
  const top = offsets.map(([x, y]) => [origin[0] + x, origin[1] + y - h]);
  return { body: k.pathOf(pts, true), surface: k.pathOf(top, true) };
}

function water(fraction) {
  const { body, surface } = waterPath(fraction);
  return `<path d="${body}" fill="#B98742" fill-opacity=".22"/><path d="${surface}" fill="#B98742" fill-opacity=".18" stroke="#B98742" stroke-width=".7"/>`;
}

const label = "A coffee scale with a glass server on its platform and a V60 dripper sitting on the server. The scale's display shows the grams poured and the time left.";
const layers = {
  back: [scale(), glassBack()],
  front: [glassFront(), dripper()],
};
for (const theme of ["light", "dark"]) {
  for (const [name, body] of Object.entries({ back: layers.back, front: layers.front, full: [...layers.back, water(0.62), ...layers.front] })) {
    writeFileSync(join(OUT, `brew-${name}-${theme}.svg`), kohi(k.figureSvg({ width: WIDTH, height: HEIGHT, label, body, standalone: theme })));
  }
  // A check page for lines.mjs and capture.mjs, with the live parts in place
  const fig = k.figureSvg({ width: WIDTH, height: HEIGHT, label, body: [...layers.back, water(0.62), ...layers.front] });
  const page = k.pageHtml({ title: "Brew scale", theme, body: k.plateHtml({ fig, title: "Brew scale", hint: "", caption: label }) });
  writeFileSync(join(OUT, `brew-check-${theme}.html`), kohi(page));
}
writeFileSync(join(OUT, "brew-geometry.json"), JSON.stringify(geometry));
console.log("brew figure written");
