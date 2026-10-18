// Kohi tokens for the anatomy kit: the kit's tones remapped to BrewGuide's ink, paper and gold.
// Every figure is exported light and dark; colours come from Coffeebrew/Assets.xcassets and Utils/Constants.swift.
export const KOHI_CSS = `
.iso{
  --anatomy-page:#131313;--anatomy-card:#1E1E1E;--anatomy-text:#B5ADA6;--anatomy-strong:#F0ECE8;--anatomy-muted:#7A716A;
  --anatomy-paper:#1E1C1A;--anatomy-face:#24211E;--anatomy-top:#26231F;
  --anatomy-shade-0:#151311;--anatomy-shade-1:#181614;--anatomy-shade-2:#1B1917;--anatomy-shade-3:#1E1C1A;
  --anatomy-lit-top:#2E2A25;--anatomy-lit-shade:#25221E;
  --anatomy-hi:#F0ECE8;--anatomy-mid:#8E857D;--anatomy-lo:#544D46;--anatomy-faint:#38332E;--anatomy-lit:#D0A25E;
  --anatomy-halo:#000000;--anatomy-halo-opacity:.85;--anatomy-dot:#E8E2DC;
}
.iso[data-theme="light"]{
  --anatomy-page:#F9F8F5;--anatomy-card:#FFFFFF;--anatomy-text:#5E544C;--anatomy-strong:#251E19;--anatomy-muted:#8C8178;
  --anatomy-paper:#FFFDFA;--anatomy-face:#FFFFFF;--anatomy-top:#FFFFFF;
  --anatomy-shade-0:#E4DCD1;--anatomy-shade-1:#EBE4DB;--anatomy-shade-2:#F2ECE5;--anatomy-shade-3:#F8F4EF;
  --anatomy-lit-top:#FFFFFF;--anatomy-lit-shade:#F5EEE4;
  --anatomy-hi:#251E19;--anatomy-mid:#8C8178;--anatomy-lo:#B8AEA4;--anatomy-faint:#DCD4CA;--anatomy-lit:#B98742;
  --anatomy-halo:#7A6A55;--anatomy-halo-opacity:.28;--anatomy-dot:#3D332C;
}
/* Glass, the coffee bed and the LCD window */
.k-glass{fill:var(--anatomy-paper);fill-opacity:.42;stroke:none}
.k-bed{fill:#6B4A33;stroke:none}
.iso[data-theme="light"] .k-bed{fill:#7A563B}
.k-lcd{fill:#2B2622;stroke:none}
.iso[data-theme="light"] .k-lcd{fill:#3A322B}
`;

/** Adds the Kohi tokens to a standalone figure SVG from k.figureSvg({ standalone }). */
export function kohi(svg) {
  return svg.replace("</style>", `</style><style>${KOHI_CSS}</style>`);
}
