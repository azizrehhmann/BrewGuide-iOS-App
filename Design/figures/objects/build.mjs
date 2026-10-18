// Category and empty-state figures: one brewer (or object) per figure, standing on a round coaster.
//   node build.mjs   -> out/<name>-{light,dark}.svg and out/<name>-check-light.html
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "../kit/iso-kit.mjs";
import * as G from "../kit/lathe.mjs";
import { kohi } from "../kohi.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "out");
mkdirSync(OUT, { recursive: true });

const WIDTH = 320;
const HEIGHT = 260;

function figure(name, label, extents, draw, { azimuth = 45, elevation = 30, width = WIDTH, height = HEIGHT, pad = 14 } = {}) {
  const P = k.fitProjection(extents, width, height, { pad, azimuth, elevation });
  const t = tools(P);
  const body = draw(t);
  for (const theme of ["light", "dark"]) {
    writeFileSync(join(OUT, `${name}-${theme}.svg`), kohi(k.figureSvg({ width, height, label, body, standalone: theme })));
  }
  const fig = k.figureSvg({ width, height, label, body });
  writeFileSync(join(OUT, `${name}-check-light.html`), kohi(k.pageHtml({ title: name, theme: "light", body: k.plateHtml({ fig, title: name, hint: "", caption: label }) })));
  console.log("wrote", name);
}

function tools(P) {
  const at = (p) => k.iso(p, P);
  const S = (paths, style) => k.solidSvg(paths, style);
  const L = (d, style) => k.lineSvg(d, style);
  const D = (points, style) => k.dotsSvg(points, style);
  const path = (points, closed = false) => k.pathOf(points.map(at), closed);
  const up = (o) => G.frameAlong(o, [0, 0, 1]);
  const cyl = (cx, cy, r, z, h, style = {}, bevel = 0) => S(k.cylinder(cx, cy, r, z, h, P, Math.max(24, Math.round(r * 2.2)), bevel), style);
  const ring = (cx, cy, r, z, tone = "faint") => L(k.ring(cx, cy, r, z, P, Math.max(24, Math.round(r * 2.2))), { tone });
  const band = (cx, cy, r, z, tone = "faint") => L(k.sideArc(cx, cy, r, z, P, 48), { tone });
  const fillCyl = (cls, cx, cy, r, z, h, extra = "") => `<path class="${cls}" d="${k.cylinder(cx, cy, r, z, h, P, 64).fill}"${extra}/>`;
  const disc = (cls, cx, cy, r, z, extra = "") => `<path class="${cls}" d="${path(k.circleRing(cx, cy, r, 64), true)}"${extra}/>`;
  const outlineCyl = (cx, cy, r, z, h, tone = "mid") => L(k.cylinder(cx, cy, r, z, h, P, 64).outline, { tone });
  const coaster = (r = 70) =>
    [`<path class="iso-halo" d="${k.haloOf({ x: -r, y: -r, w: 2 * r, d: 2 * r, r }, -5, 5, P)}"/>`, cyl(0, 0, r, -5, 5, { tone: "lo" }, 0.8), ring(0, 0, r - 6, 0)].join("");
  // A glass vessel: tinted body behind, outline and front rim in front, with an optional liquid in between
  const glass = (cx, cy, r, z, h, { liquid = 0, liquidClass = "k-bed", liquidOpacity = 0.85, front = "" } = {}) => {
    const out = [fillCyl("k-glass", cx, cy, r, z, h), ring(cx, cy, r, z + h, "lo"), ring(cx, cy, r - 2, z + h, "faint")];
    if (liquid > 0) {
      const lh = (h - 4) * liquid;
      out.push(fillCyl(liquidClass, cx, cy, r - 2, z + 3, lh, ` fill-opacity="${liquidOpacity}"`));
      out.push(ring(cx, cy, r - 2, z + 3 + lh, "lo"));
    }
    out.push(front, outlineCyl(cx, cy, r, z, h), band(cx, cy, r, z + h, "mid"));
    return out.join("");
  };
  return { P, at, S, L, D, path, up, cyl, ring, band, fillCyl, disc, outlineCyl, coaster, glass };
}

const octagon = (cx, cy, r) => Array.from({ length: 8 }, (_, i) => [cx + r * Math.cos(((i + 0.5) * Math.PI) / 4), cy + r * Math.sin(((i + 0.5) * Math.PI) / 4)]);
const coasterExtents = (r = 70) => k.boxCorners({ x: -r, y: -r, w: 2 * r, d: 2 * r, r }, -5, 0);

// ---- Pour over: V60 on a glass server
figure(
  "cat-pour-over",
  "A V60 dripper on a glass server, standing on a coaster.",
  [...coasterExtents(), [0, 0, 112], [-38, -38, 112], [38, 38, 112]],
  ({ S, L, cyl, ring, glass, coaster, up, P, at, D }) => {
    const F = up([0, 0, 66]);
    const out = [coaster()];
    out.push(cyl(0, 0, 30, 0, 3, { tone: "lo" }));
    out.push(glass(0, 0, 28, 3, 60, { liquid: 0.45 }));
    for (const z of [22, 46]) out.push(k.solidSvg(k.slabOf({ x: 26, y: -3, w: 14, d: 6, r: 2 }, z, 5, P, 3), { tone: "mid" }));
    out.push(S(k.slabOf({ x: 36, y: -3.5, w: 6, d: 7, r: 2.5 }, 22, 29, P, 4), { tone: "mid" }));
    out.push(S(G.disc(0, 2.4, 36, G.frameAlong([0, 0, 63], [0, 0, 1]), P), { tone: "mid" }));
    out.push(S(G.solidOf([[0, 9], [44, 33], [46, 34]], F, P), { tone: "hi", crease: "lo" }));
    out.push(`<path class="k-bed" d="${k.pathOf(k.circleRing(0, 0, 26, 64).map(([x, y]) => at([x, y, 104])), true)}"/>`);
    out.push(ring(0, 0, 32.4, 112, "lo"), ring(0, 0, 26, 104, "lo"));
    return out.join("");
  },
);

// ---- Immersion: French press
figure(
  "cat-immersion",
  "A French press: a glass beaker in a steel frame with the plunger raised.",
  [...coasterExtents(), [0, 0, 120], [44, 0, 80]],
  ({ S, cyl, ring, band, glass, coaster, P, D, at, L }) => {
    const out = [coaster()];
    out.push(cyl(0, 0, 30, 0, 5, { tone: "mid" }, 0.6));
    for (const [x, y] of [[-24, -14], [24, -14], [0, 28]]) out.push(cyl(x, y, 3, -0.1, 0.1, { tone: "lo" }));
    out.push(glass(0, 0, 26, 5, 70, { liquid: 0.66, front: ring(0, 0, 24, 54, "mid") }));
    // Plunger rod from the mesh up through the lid to the knob
    out.push(cyl(0, 0, 1.6, 54, 21, { tone: "mid" }));
    // Frame straps around the glass: only their front faces show
    for (const z of [12, 66]) out.push(band(0, 0, 27.5, z, "mid"), band(0, 0, 27.5, z + 4, "mid"), L(k.cylinder(0, 0, 27.5, z, 4, P, 64).outline, { tone: "mid" }));
    out.push(cyl(0, 0, 27.5, 75, 6, { tone: "hi", crease: "lo" }, 0.6));
    out.push(ring(0, 0, 20, 81, "faint"));
    out.push(cyl(0, 0, 1.8, 81, 26, { tone: "mid" }));
    out.push(S(G.sphereOf([0, 0, 111], 6, P), { tone: "hi", lit: true }));
    // Handle: two straps and a grip on the right
    for (const z of [16, 62]) out.push(S(k.slabOf({ x: 25, y: -3, w: 16, d: 6, r: 2 }, z, 5, P, 3, 0.4), { tone: "mid" }));
    out.push(S(k.slabOf({ x: 37, y: -4, w: 8, d: 8, r: 3 }, 16, 51, P, 4, 0.5), { tone: "lo" }));
    out.push(D([at([41, 0, 20]), at([41, 0, 64])], { size: 0.45 }));
    return out.join("");
  },
);

// ---- Pressure: AeroPress on a mug
figure(
  "cat-pressure",
  "An AeroPress pressed into a mug: chamber, filter cap and plunger.",
  [...coasterExtents(), [0, 0, 150], [40, 0, 36]],
  ({ S, cyl, ring, band, coaster, P, D, at, L, path, disc }) => {
    const out = [coaster()];
    out.push(cyl(0, 0, 24, 0, 40, { tone: "hi", crease: "lo" }, 0.6));
    out.push(ring(0, 0, 21.5, 40, "lo"));
    out.push(S(k.slabOf({ x: 22, y: -3, w: 14, d: 6, r: 2 }, 10, 5, P, 3), { tone: "hi" }), S(k.slabOf({ x: 22, y: -3, w: 14, d: 6, r: 2 }, 28, 5, P, 3), { tone: "hi" }));
    out.push(S(k.slabOf({ x: 32, y: -3.5, w: 6, d: 7, r: 2.5 }, 10, 23, P, 4), { tone: "hi" }));
    // Filter cap with grip ribs, the chamber's flange, the chamber with its numbered marks
    out.push(cyl(0, 0, 17, 40, 6, { tone: "mid" }));
    out.push(L(k.knurl(0, 0, 17, 40.5, 45.5, 36, P), { tone: "lo" }));
    out.push(S(k.extrude(octagon(0, 0, 24), 46, 3, P), { tone: "mid" }));
    out.push(cyl(0, 0, 15, 49, 52, { tone: "hi", crease: "lo" }));
    const face = Math.PI / 4;
    for (const z of [62, 72, 82, 92]) {
      const c = [15 * Math.cos(face), 15 * Math.sin(face), z];
      out.push(L(path(k.circleRing(0, 0, 1, 16).map(([u, v]) => [c[0] - u * Math.sin(face), c[1] + u * Math.cos(face), z + v * 1.2]), true), { tone: "mid" }));
    }
    // Plunger: body above the chamber, top cap
    out.push(cyl(0, 0, 13, 101, 40, { tone: "mid" }));
    out.push(band(0, 0, 13, 108, "faint"));
    out.push(cyl(0, 0, 16, 141, 4, { tone: "hi", lit: true }, 0.6));
    out.push(ring(0, 0, 11, 145, "faint"));
    return out.join("");
  },
);

// ---- Cold brew: jar with a filter sock
figure(
  "cat-cold-brew",
  "A cold-brew jar: a glass jar of steeping coffee with a filter sock and a screw lid.",
  [...coasterExtents(), [0, 0, 104], [30, 30, 104]],
  ({ S, cyl, ring, band, glass, coaster, P, L, fillCyl, outlineCyl }) => {
    const out = [coaster()];
    out.push(cyl(0, 0, 30, 0, 3, { tone: "lo" }));
    const sock = [fillCyl("k-glass", 0, 0, 18, 22, 66), outlineCyl(0, 0, 18, 22, 66, "lo")];
    for (const z of [32, 42, 52, 62, 72, 82]) sock.push(band(0, 0, 18, z, "faint"));
    out.push(glass(0, 0, 29, 3, 86, { liquid: 0.72, liquidOpacity: 0.75, front: sock.join("") }));
    out.push(cyl(0, 0, 30.5, 89, 9, { tone: "mid" }, 0.5));
    out.push(L(k.knurl(0, 0, 30.5, 90, 97, 60, P), { tone: "lo" }));
    out.push(cyl(0, 0, 6, 98, 4, { tone: "hi", lit: true }, 0.4));
    return out.join("");
  },
);

// ---- Stovetop: moka pot on a burner grate
figure(
  "cat-stovetop",
  "A moka pot on a burner grate: octagonal boiler, funnel waist, collector, lid and handle.",
  [...coasterExtents(), [0, 0, 118], [44, 0, 100]],
  ({ S, cyl, ring, coaster, P, L, D, at }) => {
    const out = [coaster()];
    // Burner grate: a ring and four arms
    out.push(cyl(0, 0, 40, 0, 3, { tone: "lo" }));
    out.push(ring(0, 0, 34, 3, "faint"));
    for (const a of [0, 1, 2, 3]) {
      const ang = (a * Math.PI) / 2 + Math.PI / 4;
      const x = 30 * Math.cos(ang);
      const y = 30 * Math.sin(ang);
      out.push(S(k.slabOf({ x: x - 4, y: y - 4, w: 8, d: 8, r: 1 }, 3, 4, P, 2), { tone: "lo" }));
    }
    out.push(S(k.extrude(octagon(0, 0, 24), 7, 42, P, { bevel: 0.6 }), { tone: "mid" }));
    out.push(L(k.ringSeam(octagon(0, 0, 24), 15, P), { tone: "faint" }));
    out.push(S(k.extrude(octagon(0, 0, 16), 49, 7, P), { tone: "lo" }));
    out.push(S(k.extrude(octagon(0, 0, 21), 56, 40, P, { bevel: 0.6 }), { tone: "mid" }));
    out.push(S(k.extrude(octagon(0, 0, 22), 96, 4, P, { bevel: 0.5 }), { tone: "hi", crease: "lo" }));
    out.push(cyl(0, 0, 4, 100, 9, { tone: "lo" }, 0.4));
    // Safety valve on the boiler's front face
    out.push(D([at([16, 16, 30])], { size: 1.6, tone: "mid" }));
    // Handle: a bracket on the collector and a bakelite grip
    out.push(S(k.slabOf({ x: 19, y: -3, w: 10, d: 6, r: 1.5 }, 82, 6, P, 3), { tone: "mid" }));
    out.push(S(k.slabOf({ x: 26, y: -4, w: 9, d: 8, r: 3 }, 58, 34, P, 4, 0.5), { tone: "lo" }));
    return out.join("");
  },
);

// ---- Machine: espresso group head, portafilter and cup on the drip tray
figure(
  "cat-machine",
  "The front of an espresso machine: group head, portafilter with its handle, and a cup on the drip tray.",
  [...k.boxCorners({ x: -60, y: -50, w: 120, d: 110, r: 6 }, 0, 120), [70, 60, 60]],
  ({ S, cyl, ring, band, P, L, D, at, path }) => {
    const out = [`<path class="iso-halo" d="${k.haloOf({ x: -60, y: -50, w: 120, d: 110, r: 8 }, 0, 6, P)}"/>`];
    // Body and drip tray with its grate
    out.push(S(k.slabOf({ x: -60, y: -50, w: 120, d: 56, r: 6 }, 0, 120, P, 6, 1), { tone: "mid", inner: L(k.sideSeam({ x: -60, y: -50, w: 120, d: 56, r: 6 }, 108, P, 6), { tone: "faint" }) }));
    const tray = { x: -54, y: 6, w: 108, d: 50, r: 4 };
    out.push(S(k.slabOf(tray, 0, 12, P, 4, 0.6), { tone: "lo" }));
    const grate = [];
    for (let x = tray.x + 8; x <= tray.x + tray.w - 8; x += 8) grate.push(k.lineOnTop([x, tray.y + 6], [x, tray.y + tray.d - 6], 12, P));
    out.push(L(grate.join(""), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(tray, 5), 12, P, 4), { tone: "lo" }));
    // Cup on the tray under the spouts
    out.push(cyl(0, 30, 12, 12, 22, { tone: "hi", crease: "lo" }, 0.4));
    out.push(ring(0, 30, 10, 34, "lo"));
    out.push(S(k.slabOf({ x: 10, y: 27, w: 9, d: 6, r: 2 }, 18, 10, P, 3), { tone: "hi" }));
    // Group head block, the group and the portafilter with its handle reaching to the right
    out.push(S(k.slabOf({ x: -22, y: 6, w: 44, d: 22, r: 4 }, 92, 16, P, 4, 0.6), { tone: "mid" }));
    out.push(cyl(0, 22, 17, 80, 12, { tone: "hi", crease: "lo" }, 0.6));
    out.push(cyl(0, 22, 15, 70, 10, { tone: "hi", lit: true }, 0.6));
    out.push(cyl(-5, 22, 2, 62, 8, { tone: "mid" }), cyl(5, 22, 2, 62, 8, { tone: "mid" }));
    out.push(S(k.slabOf({ x: 14, y: 18, w: 52, d: 9, r: 4 }, 72, 7, P, 4, 0.5), { tone: "lo" }));
    // Pressure gauge on the body's front face
    out.push(D([at([-40, 6, 96]), at([40, 6, 96])], { size: 0.5 }));
    return out.join("");
  },
);

// ---- Empty Journal: an open brew log, a pencil and a cup ring
figure(
  "empty-journal",
  "An open brew log with ruled pages, a pencil lying across it and a coffee cup ring on the left page.",
  [...k.boxCorners({ x: -80, y: -52, w: 160, d: 104, r: 4 }, -3, 10)],
  ({ S, L, P, ring, at, path, D }) => {
    const cover = { x: -80, y: -52, w: 160, d: 104, r: 4 };
    const left = { x: -76, y: -48, w: 74, d: 96, r: 2 };
    const right = { x: 2, y: -48, w: 74, d: 96, r: 2 };
    const out = [`<path class="iso-halo" d="${k.haloOf(cover, -3, 3, P)}"/>`];
    out.push(S(k.slabOf(cover, -3, 3, P, 4, 0.6), { tone: "lo" }));
    out.push(S(k.slabOf(left, 0, 4, P, 3, 0.6), { tone: "hi", crease: "lo" }));
    out.push(S(k.slabOf(right, 0, 4, P, 3, 0.6), { tone: "hi", crease: "lo" }));
    // Ruled lines on both pages, a margin rule on the right page
    for (const page of [left, right]) {
      const rules = [];
      for (let y = page.y + 14; y < page.y + page.d - 8; y += 8) rules.push(k.lineOnTop([page.x + 6, y], [page.x + page.w - 6, y], 4, P));
      out.push(L(rules.join(""), { tone: "faint", free: true }));
    }
    out.push(L(k.lineOnTop([right.x + 14, right.y + 4], [right.x + 14, right.y + right.d - 4], 4, P), { tone: "lo", free: true }));
    // Cup ring: two concentric stains
    out.push(L(k.ring(-40, -8, 15, 4, P, 48), { tone: "mid" }), L(k.ring(-40, -8, 13.5, 4, P, 48), { tone: "faint" }));
    // Pencil lying on the right page, along y, with a sharpened tip
    const F = G.frameAlong([40, -40, 7], [0, 1, 0]);
    out.push(S(G.prismOf(F, octagon(0, 0, 3.4).slice(0, 8).map(([x, y]) => [x, y]), 0, 70, P), { tone: "hi", lit: true }));
    out.push(S(G.solidOf([[70, 3.4], [80, 0.6]], F, P), { tone: "mid" }));
    out.push(S(G.disc(-6, 0, 3.4, F, P), { tone: "lo" }));
    return out.join("");
  },
  { height: 230 },
);

// ---- Empty Pantry: canister, valve bag and scoop
figure(
  "empty-pantry",
  "A coffee canister with its lid, a valve bag of beans standing beside it, and a scoop on the coaster.",
  [...coasterExtents(), [0, 0, 96], [50, -10, 92]],
  ({ S, L, P, cyl, ring, band, coaster, D, at }) => {
    const out = [coaster()];
    // Valve bag behind and to the right
    const bag = { x: 18, y: -46, w: 42, d: 18, r: 4 };
    out.push(S(k.slabOf(bag, 0, 86, P, 4, 0.6), { tone: "hi", crease: "lo", inner: L(k.sideSeam(bag, 76, P, 4), { tone: "faint" }) }));
    out.push(S(k.slabOf({ x: 18, y: -46, w: 42, d: 18, r: 2 }, 86, 5, P, 3, 0.4), { tone: "mid" }));
    out.push(D([at([48, -28, 64])], { size: 2.4, tone: "lo" }), D([at([48, -28, 64])], { size: 1, tone: "mid" }));
    // Canister with a band label and a lid
    out.push(cyl(-14, 8, 30, 0, 74, { tone: "mid" }, 0.6));
    out.push(cyl(-14, 8, 30.6, 30, 16, { tone: "hi", lit: true }));
    out.push(cyl(-14, 8, 31.5, 74, 7, { tone: "hi", crease: "lo" }, 0.6));
    out.push(cyl(-14, 8, 5, 81, 6, { tone: "lo" }, 0.4));
    // Scoop in front
    out.push(cyl(36, 44, 9, 0, 7, { tone: "hi" }, 0.4));
    out.push(ring(36, 44, 7.4, 7, "lo"));
    out.push(S(k.slabOf({ x: 42, y: 51, w: 22, d: 5, r: 2 }, 3, 3, P, 3), { tone: "mid" }));
    return out.join("");
  },
);
