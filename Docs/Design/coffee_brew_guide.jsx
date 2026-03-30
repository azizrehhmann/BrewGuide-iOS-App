import { useState, useEffect, useRef, useCallback } from "react";

const DB = {"V60 Pour Over (Standard)":{"cat":"Pour Over","device":"Hario V60 Dripper","grind":"Medium-Fine (table salt)","dose":"15-30","water":"250-500","ratio":"1:16.7","tempC":"90-96","time":"2:30 - 3:30","filter":"Paper cone (V60)","diff":"3","cups":"1-2","flavor":"Clean, bright, nuanced, floral/fruity notes shine","body":"Light","clarity":"High","bestFor":"Flavor purists; single-origin light roasts","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Fold V60 paper filter seam; place in dripper on server. Rinse with hot water; discard."},{"t":"0:00","i":"Add ground coffee; shake to level. Start timer."},{"t":"0:00","i":"Bloom: pour 2x coffee weight of water in spiral from center out."},{"t":"0:00-0:30","i":"Wait 30 seconds for bloom; coffee releases CO₂ and expands."},{"t":"0:30","i":"Begin main pour: slow concentric circles from center outward; avoid filter edges."},{"t":"0:30-2:00","i":"Pour steadily; maintain water level about halfway up the slurry."},{"t":"2:00-2:30","i":"Complete final pour to target water weight."},{"t":"2:30-3:30","i":"Allow full drawdown. Aim for flat coffee bed."}],"notes":["Adjust grind finer if too fast (<2:30) or coarser if too slow (>3:30)."]},
"V60 – James Hoffmann Ultimate":{"cat":"Pour Over","device":"Hario V60 Dripper","grind":"Medium-Fine","dose":"30","water":"500","ratio":"1:16.7","tempC":"95-100","time":"3:30","filter":"Paper cone (V60), rinsed","diff":"3","cups":"2","flavor":"Balanced, sweet, clean with full extraction","body":"Medium","clarity":"High","bestFor":"Repeatable everyday pour over; light-medium roasts","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"0:00","i":"Add ground coffee to V60; make a well in the center with finger"},{"t":"0:00","i":"Start timer; pour 60g water (2x dose) in spiral from center outward"},{"t":"0:10","i":"Swirl V60 in circular motion until slurry is even; no dry clumps"},{"t":"0:10-0:45","i":"Let coffee bloom (CO₂ escaping); wait up to 45 seconds"},{"t":"0:45","i":"Begin main pour: spiral pour aggressively to reach 300g by 1:15"},{"t":"1:15","i":"Slow second pour: gently pour remaining water to reach 500g by 1:45"},{"t":"1:45","i":"Stir once clockwise, once counter-clockwise with spoon"},{"t":"1:50","i":"Allow V60 to drain slightly, then give a final gentle swirl"},{"t":"1:55-3:30","i":"Wait for full drawdown; aim for flat coffee bed; total time ~3:30"}],"notes":[]},
"V60 – Tetsu Kasuya 4:6 Method":{"cat":"Pour Over","device":"Hario V60","grind":"Medium-Coarse","dose":"20","water":"300","ratio":"1:15","tempC":"93","time":"3:30","filter":"Paper cone (V60), rinsed","diff":"2","cups":"1-2","flavor":"Adjustable sweetness/acidity; balanced and forgiving","body":"Medium","clarity":"High","bestFor":"Beginners; those wanting control over sweetness vs acidity","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"0:00","i":"Pour 60g water slowly in concentric circle over 10 seconds (1st pour = 40% part 1)"},{"t":"0:00-0:45","i":"Wait for water to drain completely before next pour"},{"t":"0:45","i":"Pour 60g water (2nd pour = 40% part 2); wait for full drain"},{"t":"1:25","i":"Pour 60g water (3rd pour = 60% part 1); wait for full drain"},{"t":"2:05","i":"Pour 60g water (4th pour = 60% part 2); wait for full drain"},{"t":"2:35","i":"Pour 60g water (5th pour = 60% part 3); wait for full drain"},{"t":"3:30","i":"Extraction complete; remove V60 and serve"}],"notes":["For more sweetness: make 1st pour smaller (50g), 2nd pour larger (70g)","For more acidity: make 1st pour larger (70g), 2nd pour smaller (50g)"]},
"V60 – Matt Winton Five Pour":{"cat":"Pour Over","device":"Hario V60 Dripper","grind":"Medium-Fine","dose":"15","water":"250","ratio":"1:16.7","tempC":"95-98","time":"2:30 - 3:30","filter":"Paper cone (V60), rinsed","diff":"3","cups":"1","flavor":"Even extraction, sweet, balanced clarity","body":"Light-Medium","clarity":"High","bestFor":"Small single-cup brews; consistency seekers","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"0:00","i":"Rinse paper filter; add 15g coffee to V60. Start timer."},{"t":"0:00","i":"Pour ~50g water (3.3× dose) for bloom; swirl to saturate all grounds."},{"t":"0:00-0:45","i":"Wait 45 seconds for bloom."},{"t":"0:45","i":"Pour #2: ~50g water in gentle concentric circles."},{"t":"1:05","i":"Pour #3: ~50g water."},{"t":"1:25","i":"Pour #4: ~50g water."},{"t":"1:45","i":"Pour #5: ~50g water (total now 250g)."},{"t":"2:00","i":"Give V60 a final gentle swirl to level the bed."},{"t":"2:30-3:30","i":"Wait for full drawdown. Aim for flat coffee bed at bottom."}],"notes":["Five equal pours give consistent, even extraction — ideal for small 1-cup brews."]},
"Chemex":{"cat":"Pour Over","device":"Chemex Brewer (6 or 8 cup)","grind":"Medium-Coarse (kosher salt)","dose":"30-42","water":"480-600","ratio":"1:15 to 1:16","tempC":"93-99","time":"3:30 - 4:30","filter":"Chemex thick paper filter","diff":"3","cups":"2-4","flavor":"Ultra-clean, smooth, bright, tea-like clarity","body":"Light","clarity":"Very High","bestFor":"Artisanal coffee lovers; multiple servings; light roasts","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Place Chemex filter (3 layers toward spout); rinse with hot water; discard"},{"t":"0:00","i":"Add ground coffee; shake gently to level. Start timer."},{"t":"0:00","i":"Pour 50-70g water to bloom; wet all grounds evenly in center spiral"},{"t":"0:00-0:45","i":"Wait 30-45 seconds for bloom (coffee releases CO₂ and expands)"},{"t":"0:45","i":"Begin main pour: slow spiral from center outward; avoid filter edges"},{"t":"0:45-2:45","i":"Continue pouring steadily until all water is in Chemex"},{"t":"2:45-4:00","i":"Allow full drawdown; aim for 3:30-4:30 total time"},{"t":"4:00","i":"Remove filter and discard; serve immediately"}],"notes":["If too slow (>4:30): coarsen grind. If too fast (<3:00): fine-tune finer."]},
"Kalita Wave":{"cat":"Pour Over","device":"Kalita Wave 155/185 Dripper","grind":"Medium","dose":"20-26","water":"320-400","ratio":"1:16","tempC":"90-96","time":"3:00 - 4:00","filter":"Kalita Wave flat-bottom paper","diff":"2","cups":"1-2","flavor":"Even, balanced, forgiving extraction; sweet and smooth","body":"Medium","clarity":"High","bestFor":"Beginners to pour over; consistent results","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Place Kalita Wave filter in dripper; rinse with hot water on server. Discard rinse water."},{"t":"0:00","i":"Add ground coffee; shake to level. Start timer."},{"t":"0:00","i":"Bloom: pour 40-50g water to saturate all grounds; gentle swirl."},{"t":"0:00-0:45","i":"Wait 30-45 seconds for bloom."},{"t":"0:45","i":"Pour in slow concentric circles to ~60% of total water weight."},{"t":"1:30","i":"Pause briefly; let water draw down to near slurry level."},{"t":"1:45","i":"Resume pouring to reach final water weight; keep gentle, centered pours."},{"t":"2:30-4:00","i":"Full drawdown complete. Flat bed = even extraction."}],"notes":["The flat bottom + 3 drain holes make this very forgiving for beginners."]},
"Nel Drip (Flannel Drip)":{"cat":"Pour Over","device":"Nel drip stand + flannel filter","grind":"Medium to Medium-Coarse","dose":"20-25","water":"300-360","ratio":"1:14 to 1:16","tempC":"85-90","time":"3:00 - 5:00","filter":"Reusable flannel cloth","diff":"4","cups":"1-2","flavor":"Silky, round, full body with gentle sweetness; oils pass through","body":"Medium-Full","clarity":"Medium","bestFor":"Japanese coffee culture; rich mouthfeel seekers","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Soak flannel filter in hot water. Wring out excess. Attach to stand."},{"t":"Prep","i":"Pre-wet filter with hot water to remove residual flavor. Discard rinse water."},{"t":"0:00","i":"Add 20-25g ground coffee to flannel filter. Create a small well in center."},{"t":"0:00","i":"Start timer. Pour ~40-50g water gently into center for bloom."},{"t":"0:00-0:30","i":"Wait 30 seconds. Coffee swells and releases CO₂."},{"t":"0:30","i":"Begin slow center pour: thin stream, center spiraling gently outward."},{"t":"0:30-3:00","i":"Continue in slow pulses. Keep water level low — do NOT flood the filter."},{"t":"3:00-5:00","i":"Allow remaining water to drip through fully."}],"notes":["Water temp is LOWER than V60 (85-90°C) — produces a rounder, sweeter cup.","Flannel lets oils pass through (unlike paper), giving a silky mouthfeel."]},
"Osmotic Flow V60":{"cat":"Pour Over","device":"Hario V60 + Cafec Flower Dripper","grind":"Medium","dose":"20","water":"300","ratio":"1:15","tempC":"92-96","time":"3:00 - 4:00","filter":"Paper (Cafec or V60)","diff":"4","cups":"1-2","flavor":"Ultra-even extraction; sweet, complex, low bitterness","body":"Medium","clarity":"Very High","bestFor":"Advanced brewers; extraction enthusiasts","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Rinse paper filter in V60 or Cafec Flower Dripper. Place on server."},{"t":"0:00","i":"Add 20g coffee (medium grind). Level bed."},{"t":"0:00","i":"Start timer. Pour ~50g water for bloom; wait 45 seconds."},{"t":"0:45","i":"Begin ultra-slow center pour: pour ONLY in the very center in a thin stream."},{"t":"0:45-3:00","i":"Continue slow center pour. Water should barely rise above the coffee bed level."},{"t":"3:00","i":"When all 300g has been poured, allow final drawdown."},{"t":"3:00-4:00+","i":"Drawdown may take longer than standard V60 — that's expected."}],"notes":["Water percolates outward through the coffee bed via osmotic pressure, not gravity flooding.","Pour height: LOW (1-2cm above slurry) to minimize agitation."]},
"Scott Rao V60 Technique":{"cat":"Pour Over","device":"Hario V60 Dripper","grind":"Medium-Fine","dose":"22","water":"360","ratio":"1:16 to 1:17","tempC":"95-97","time":"3:00 - 3:30","filter":"Paper cone (V60), rinsed","diff":"3","cups":"1-2","flavor":"High extraction, sweet, balanced; Rao Spin technique for even bed","body":"Medium","clarity":"High","bestFor":"Pour over enthusiasts; extraction-focused brewers","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Rinse V60 filter; preheat dripper and server. Add coffee; create flat bed."},{"t":"0:00","i":"Start timer. Pour 60-66g water for bloom; aggressive pour to saturate."},{"t":"0:00-0:10","i":"Use spoon to stir/excavate grounds ensuring all are wet (the 'Rao Spin')."},{"t":"0:10-0:45","i":"Wait for bloom. CO₂ escapes."},{"t":"0:45","i":"Begin main pour: continuous slow spiral from center out and back. Do NOT stop."},{"t":"0:45-1:45","i":"One single uninterrupted pour to 360g total. Keep water level steady."},{"t":"1:45","i":"Perform gentle 'Rao Spin' – swirl dripper once to flatten bed."},{"t":"1:45-3:00","i":"Allow full drawdown. Flat bed at end."}],"notes":["Key principle: one continuous main pour + single swirl = even extraction."]},
"Melitta Pour Over (Classic Flat Bottom)":{"cat":"Pour Over","device":"Melitta cone or flat-bottom dripper","grind":"Medium","dose":"20-30","water":"340-500","ratio":"1:16 to 1:17","tempC":"90-96","time":"3:00 - 4:00","filter":"Melitta paper filter","diff":"1","cups":"1-4","flavor":"Clean, balanced, straightforward; the original paper-filter pour over","body":"Medium","clarity":"Medium-High","bestFor":"Beginners; the birthplace of paper-filtered coffee (1908 Germany)","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila","Guatemalan Antigua","Panama Geisha"],"steps":[{"t":"Prep","i":"Place Melitta paper filter in flat-bottom dripper. Set on mug or carafe."},{"t":"Prep","i":"Rinse filter with hot water to remove papery taste. Discard rinse water."},{"t":"0:00","i":"Add ground coffee. Level bed. Start timer."},{"t":"0:00","i":"Pour ~40-60g water over grounds for bloom. Wet evenly."},{"t":"0:00-0:30","i":"Wait 30 seconds for bloom (CO₂ release)."},{"t":"0:30","i":"Begin main pour in slow concentric circles from center outward."},{"t":"0:30-2:30","i":"Pour steadily in 2-3 pulses, allowing partial drawdown between pours."},{"t":"2:30-4:00","i":"Allow full drawdown. Aim for flat, even coffee bed."}],"notes":["Flat-bottom design creates more even extraction than V60 cone — very forgiving.","Invented by Melitta Bentz in 1908 — the original paper-filtered pour over."]},
"French Press (Standard)":{"cat":"Immersion","device":"French Press (Cafetière)","grind":"Coarse (sea salt)","dose":"30","water":"500","ratio":"1:16 to 1:17","tempC":"93-96","time":"4:00","filter":"Metal mesh plunger screen","diff":"1","cups":"2-4","flavor":"Bold, rich, full-bodied with oils and sediment","body":"Full","clarity":"Low","bestFor":"Beginners; those who love rich, heavy coffee","beans":["Brazilian Santos","Sumatra Mandheling","Colombian Supremo","Ethiopian Sidama"],"steps":[{"t":"0:00","i":"Preheat French press with hot water; discard."},{"t":"0:00","i":"Add 30g coarse-ground coffee to French press."},{"t":"0:00","i":"Start timer. Pour all 500g water vigorously to saturate all grounds."},{"t":"0:15","i":"Stir once briefly with a spoon to break up any dry clumps."},{"t":"0:20","i":"Place lid on French press with plunger pulled up. Do not press yet."},{"t":"4:00","i":"Press plunger down slowly and evenly all the way to the bottom."},{"t":"4:00","i":"Pour immediately into cups to prevent over-extraction."}],"notes":["Bitter = grind coarser or steep less. Sour/weak = grind finer or steep longer."]},
"French Press – James Hoffmann":{"cat":"Immersion","device":"French Press (Cafetière)","grind":"Medium (finer than traditional)","dose":"30","water":"500","ratio":"1:16.7","tempC":"95-96","time":"9:00 - 12:00","filter":"Metal mesh (plunger not pressed to bottom)","diff":"2","cups":"2-4","flavor":"Clean yet full-bodied; dramatically reduced silt; nuanced","body":"Medium-Full","clarity":"Medium-High","bestFor":"Cleaner French press lovers; those who dislike sediment","beans":["Brazilian Santos","Sumatra Mandheling","Colombian Supremo","Ethiopian Sidama"],"steps":[{"t":"0:00","i":"Add 30g medium-ground coffee to French press (do NOT use coarse)"},{"t":"0:00","i":"Start timer; pour all 500g water in one go; saturate all grounds evenly"},{"t":"0:00-4:00","i":"Wait 4 minutes with NO lid on; do not touch. A crust will form on top"},{"t":"4:00","i":"Break the crust by stirring gently (clockwise + counter-clockwise)"},{"t":"4:15","i":"Use two spoons to scoop off foam and floating particles from surface"},{"t":"4:30","i":"Place lid on (plunger NOT pressed down); wait 5-8 more minutes"},{"t":"9:00-12:00","i":"Gently push plunger down ONLY to just below the surface (not to bottom)"},{"t":"9:00-12:00","i":"Pour gently into cup; leave last ~20ml to avoid disturbing settled grounds"}],"notes":["Key difference: plunger acts as strainer, NOT as press; grounds settle naturally"]},
"Cold Brew (Immersion)":{"cat":"Immersion","device":"Mason jar, French press, or cold brew pitcher","grind":"Coarse (very coarse, like raw sugar)","dose":"70-100","water":"700-1000","ratio":"1:8 to 1:10 (concentrate)","tempC":"Room temp or refrigerator (2-22)","time":"12-24 hours","filter":"Fine mesh strainer + cheesecloth or paper","diff":"1","cups":"4-8 (concentrate)","flavor":"Smooth, sweet, low acidity, chocolatey, refreshing","body":"Medium-Full","clarity":"Medium","bestFor":"Hot weather; prep-ahead; those sensitive to acidity","beans":["Brazilian Santos","Sumatra Mandheling","Colombian Supremo","Ethiopian Sidama"],"steps":[{"t":"Step 1","i":"Grind coffee very coarse (like raw sugar or coarse cornmeal)"},{"t":"Step 2","i":"Add coffee to mason jar, French press, or cold brew pitcher"},{"t":"Step 3","i":"Pour cold or room temperature filtered water over grounds"},{"t":"Step 4","i":"Stir gently to ensure all grounds are saturated"},{"t":"Step 5","i":"Cover container; place in refrigerator (or leave at room temp for faster extraction)"},{"t":"Step 6","i":"Steep for 12-24 hours (fridge = 18-24h; room temp = 12-16h)"},{"t":"Step 7","i":"Strain through fine mesh filter, then through cheesecloth or paper filter"},{"t":"Step 8","i":"Concentrate can be diluted 1:1 with water or milk; serve over ice"}],"notes":["Refrigerator cold brew = smoother, sweeter; room temp = more extraction, bolder"]},
"Cupping (Professional Tasting)":{"cat":"Immersion","device":"Cupping bowl (6-8 oz ceramic)","grind":"Coarse (slightly coarser than French press)","dose":"8.25","water":"150","ratio":"1:18.18 (SCA standard)","tempC":"93","time":"4:00 steep + 5-8 min cooling","filter":"None (grounds float, then scooped)","diff":"2","cups":"1 (tasting)","flavor":"Reveals true character; used to evaluate origin, defects, quality","body":"Full","clarity":"Low","bestFor":"Coffee professionals; quality evaluation; sensory analysis","beans":["Brazilian Santos","Sumatra Mandheling","Colombian Supremo","Ethiopian Sidama"],"steps":[{"t":"Prep","i":"Grind 8.25g per bowl (slightly coarser than French press). Set out cupping bowls."},{"t":"Prep","i":"Prepare tasting spoons, rinse water, and spit cup."},{"t":"Step 1","i":"Evaluate DRY FRAGRANCE: lean in and smell the dry grounds in each bowl."},{"t":"0:00","i":"Start timer. Pour 150g of 93°C water directly onto grounds in each bowl."},{"t":"0:00-4:00","i":"Wait exactly 4 minutes. A crust of grounds forms on the surface."},{"t":"4:00","i":"BREAK THE CRUST: push grounds aside with spoon 3 times. Inhale aroma deeply."},{"t":"4:15","i":"Skim off foam and floating grounds with two spoons. Discard into waste bowl."},{"t":"4:30-9:00","i":"Let coffee cool 5-8 minutes. Grounds settle to bottom."},{"t":"9:00+","i":"TASTE: slurp aggressively from spoon to spray coffee across entire palate."}],"notes":["SCA standard: 8.25g per 150ml (1:18.18 ratio). Water just off boil.","Never stir after breaking crust — grounds must remain settled at bottom."]},
"Clever Dripper":{"cat":"Immersion/Hybrid","device":"Clever Coffee Dripper","grind":"Medium-Coarse","dose":"20-21","water":"320-336","ratio":"1:16","tempC":"93-96","time":"3:00 - 4:00","filter":"Melitta #4 paper filter","diff":"1","cups":"1-2","flavor":"Best of French press body + pour over clarity; balanced","body":"Medium","clarity":"Medium-High","bestFor":"Beginners; cafe environments; medium-dark roasts","beans":["Colombian Huila","Ethiopian Yirgacheffe","Kenyan AA"],"steps":[{"t":"Prep","i":"Place Melitta #4 filter in Clever Dripper; rinse with hot water; drain off dripper stand"},{"t":"0:00","i":"Add ground coffee; pour all water in one go (no bloom needed); start timer"},{"t":"0:00","i":"Place lid on to retain heat"},{"t":"1:00","i":"Stir gently to break any crust of floating grounds"},{"t":"2:30","i":"Place Clever Dripper on carafe/mug to release the valve and begin drawdown"},{"t":"2:30-3:15","i":"Drawdown takes 30-45 seconds through paper filter"},{"t":"3:15","i":"Remove Clever Dripper; serve coffee"}],"notes":["If drawdown is too fast: grind finer. If too slow: grind coarser."]},
"Hario Switch (Immersion Dripper)":{"cat":"Immersion/Hybrid","device":"Hario Switch 02/03 (V60 shape with valve)","grind":"Medium to Medium-Fine","dose":"15-20","water":"240-320","ratio":"1:15 to 1:16","tempC":"92-96","time":"3:00 - 3:30","filter":"V60 paper filter (tabbed)","diff":"2","cups":"1-2","flavor":"Combines immersion body with pour over clarity; sweet, balanced, clean","body":"Medium","clarity":"High","bestFor":"Those who want Clever Dripper convenience with V60 filter quality","beans":["Colombian Huila","Ethiopian Yirgacheffe","Kenyan AA"],"steps":[{"t":"Prep","i":"Place V60 tabbed paper filter in Switch; rinse with hot water. Close the valve (switch down)."},{"t":"0:00","i":"Add ground coffee. Start timer. Pour all water in one go."},{"t":"0:05","i":"Stir gently 2-3 times to ensure all grounds are saturated."},{"t":"0:05-2:00","i":"Wait for full steep with valve closed (immersion phase)."},{"t":"2:00","i":"Open the valve (switch up); coffee begins to drain through paper filter."},{"t":"2:00-3:00","i":"Drawdown takes ~45-60 seconds through V60 paper."},{"t":"3:00","i":"Remove dripper. Serve."}],"notes":["Combines the body of Clever Dripper with the filter clarity of V60. Very beginner-friendly."]},
"Japanese Iced Coffee (Flash Brew)":{"cat":"Pour Over / Iced","device":"V60, Chemex, or any pour over + ice","grind":"Medium-Fine (slightly finer than hot pour over)","dose":"20-25","water":"150-175 hot + 100-125 ice","ratio":"1:16 total (half water as ice)","tempC":"92-96","time":"2:00 - 3:00","filter":"Paper filter (V60 or Chemex)","diff":"3","cups":"1-2","flavor":"Bright, aromatic, retains acidity; instantly chilled","body":"Light-Medium","clarity":"High","bestFor":"Iced coffee lovers who want brightness and aroma","beans":["Ethiopian Yirgacheffe","Kenyan AA","Colombian Huila"],"steps":[{"t":"Prep","i":"Place 100-125g of ice cubes into server/carafe below the dripper."},{"t":"Prep","i":"Set up V60/Chemex with rinsed paper filter on top of ice-filled server."},{"t":"0:00","i":"Add ground coffee (grind slightly finer than normal hot pour over). Start timer."},{"t":"0:00","i":"Bloom with 40-50g hot water; wait 30 seconds."},{"t":"0:30","i":"Pour remaining hot water in slow spirals (total hot water = ~60% of normal recipe)."},{"t":"1:30-2:30","i":"Complete pour; allow full drawdown. Hot coffee drips directly onto ice."},{"t":"Done","i":"Swirl server to melt remaining ice and chill evenly. Pour into glass."}],"notes":["Retains aroma and brightness unlike cold brew. Use total 1:16 ratio (ice counts as water)."]},
"AeroPress (Standard/Upright)":{"cat":"AeroPress","device":"AeroPress Original or Clear","grind":"Medium-Fine (finer than drip)","dose":"14-18","water":"200-230","ratio":"1:15","tempC":"80-92","time":"1:00 - 2:00","filter":"AeroPress paper micro-filter (or metal)","diff":"2","cups":"1","flavor":"Clean, smooth, sweet, versatile; low bitterness","body":"Medium","clarity":"High","bestFor":"Travelers; quick brew; versatile experimenters","beans":["Italian Espresso Blend","Ethiopian Guji","Colombian Nariño","Brazilian Cerrado"],"steps":[{"t":"Prep","i":"Place paper filter in cap; rinse. Attach cap to AeroPress chamber; place on mug."},{"t":"0:00","i":"Add ground coffee. Start timer. Pour all water in steadily."},{"t":"0:10","i":"Stir gently 3-5 times back and forth."},{"t":"0:10-1:00","i":"Let coffee steep (some will drip through — this is normal in upright method)."},{"t":"1:00","i":"Insert plunger and press down slowly with steady pressure for 20-30 seconds."},{"t":"1:20-1:30","i":"Stop pressing when you hear a hiss (air pushing through)."},{"t":"Done","i":"Remove AeroPress. Optionally dilute with hot water for an Americano-style cup."}],"notes":["Lower water temp (80°C) = sweeter; higher (92°C) = more extraction/bitterness."]},
"AeroPress (Inverted Method)":{"cat":"AeroPress","device":"AeroPress (flipped upside down)","grind":"Medium-Fine","dose":"14-18","water":"200-230","ratio":"1:12 to 1:15","tempC":"80-96","time":"1:00 - 2:30","filter":"AeroPress paper micro-filter (or metal)","diff":"2","cups":"1","flavor":"Fuller body than standard; more control over steep time","body":"Medium-Full","clarity":"High","bestFor":"Competition brewers; those wanting full immersion control","beans":["Italian Espresso Blend","Ethiopian Guji","Colombian Nariño","Brazilian Cerrado"],"steps":[{"t":"Prep","i":"Insert plunger into chamber at the 4 mark. Flip upside down (plunger on bottom)."},{"t":"Prep","i":"Place paper filter in cap; rinse with hot water. Set cap aside."},{"t":"0:00","i":"Add ground coffee to inverted chamber. Start timer."},{"t":"0:00","i":"Pour water to desired level (200-230g). Leave space for cap."},{"t":"0:10","i":"Stir gently 3-5 times back and forth."},{"t":"1:00","i":"Attach rinsed filter cap. Screw on firmly."},{"t":"1:05","i":"Carefully and confidently flip AeroPress onto cup/server. Hold firmly!"},{"t":"1:10","i":"Press plunger down slowly and steadily (~30 seconds). Stop at hiss."},{"t":"1:40","i":"Remove AeroPress. Dilute with hot water if desired."}],"notes":["Inverted = zero drip-through during steeping. Preferred by most competition brewers."]},
"AeroPress – WAC 2025 Winner (Némo Pop)":{"cat":"AeroPress","device":"AeroPress + Flow Control Filter Cap","grind":"Fine (Comandante 31 clicks, sifted at 200μm)","dose":"18","water":"100 brew + 70 bypass = 170 total","ratio":"1:5.5 brew (diluted to ~1:9.4)","tempC":"84 brew / 50 bypass","time":"~1:10","filter":"2x Paper filters in Flow Control Cap","diff":"5","cups":"1","flavor":"Juicy, sweet, high clarity; championship-level precision","body":"Light-Medium","clarity":"Very High","bestFor":"Advanced brewers; competition-style; light roast single origins","beans":["Italian Espresso Blend","Ethiopian Guji","Colombian Nariño","Brazilian Cerrado"],"steps":[{"t":"Prep","i":"Pour 70g of 50°C bypass water into carafe first"},{"t":"Prep","i":"Grind coffee (slow RPM); blow off chaff and sift out fines at 200μm"},{"t":"0:00","i":"Place AeroPress upright on carafe; add sifted ground coffee to chamber"},{"t":"0:00","i":"Pour 100g of 84°C water into AeroPress; wet all coffee grounds"},{"t":"0:25","i":"Stir in North-South-North-South then West-East-West-East pattern"},{"t":"0:50","i":"Begin pressing gently for about 20 seconds"},{"t":"1:10","i":"Press complete; coffee mixes with bypass water in carafe. Serve."}],"notes":["Uses Flow Control Filter Cap with 2x paper filters for maximum clarity","Coffee used: Ecuador Sidra, washed, 1300 MASL from Finca la Carolina"]},
"AeroPress – WAC 2024 Winner (George Stanica)":{"cat":"AeroPress","device":"AeroPress (Inverted at 4th mark)","grind":"Medium-Fine (Comandante C40 58 clicks / 870μm)","dose":"18","water":"~130 brew + bypass to 165","ratio":"1:7.2 brew (diluted to ~1:8-9)","tempC":"96 brew / room temp bypass","time":"~2:15","filter":"1x Aesir paper filter, rinsed","diff":"5","cups":"1","flavor":"Pleasant mouthfeel, sweet, balanced acidity","body":"Medium","clarity":"Very High","bestFor":"Advanced brewers; light roast Ethiopian coffees","beans":["Italian Espresso Blend","Ethiopian Guji","Colombian Nariño","Brazilian Cerrado"],"steps":[{"t":"Prep","i":"Set AeroPress inverted at the 4th mark; add 18g coffee to chamber"},{"t":"0:00","i":"1st Pour: Pour ~50g water using a Melodrip (takes 5-6 seconds)"},{"t":"0:06-0:30","i":"Wait; let coffee bloom"},{"t":"0:30","i":"2nd Pour: Pour ~80g more water (total ~130g) using Melodrip (takes ~10 sec)"},{"t":"0:45","i":"Stir gently N-S-E-W pattern for 10 seconds"},{"t":"1:00","i":"Rinse filter (1x Aesir); turn off kettle and remove lid"},{"t":"1:20","i":"Cap the AeroPress; gently remove air (takes ~10 seconds)"},{"t":"1:30","i":"Gently swirl AeroPress; place on server"},{"t":"1:35","i":"Begin pressing gently; aim for 76-79g output in 30-40 seconds"},{"t":"2:10","i":"Add warm water from kettle to ~130-135g total; add 20-30g room temp 0ppm water"}],"notes":["Water: Aquacode diluted to 85-90ppm. Coffee: Ethiopia Guji, washed, heirloom"]},
"AeroPress – James Hoffmann (Best Recipe)":{"cat":"AeroPress","device":"AeroPress (Standard upright)","grind":"Fine-Medium","dose":"11","water":"200","ratio":"1:18","tempC":"90-95","time":"2:00 - 2:30","filter":"1x paper micro-filter, rinsed","diff":"2","cups":"1","flavor":"Sweet, clean, balanced; emphasizes sweetness over strength","body":"Light-Medium","clarity":"High","bestFor":"Everyday single cup; lighter approach to AeroPress","beans":["Italian Espresso Blend","Ethiopian Guji","Colombian Nariño","Brazilian Cerrado"],"steps":[{"t":"Prep","i":"Place paper filter in cap; rinse. Assemble AeroPress upright on cup."},{"t":"0:00","i":"Add 11g coffee. Start timer. Pour all 200g water in one go. Do NOT stir."},{"t":"0:00-2:00","i":"Wait 2 full minutes. Some coffee will drip through — that's OK."},{"t":"2:00","i":"Swirl the AeroPress gently 3 times (no spoon needed)."},{"t":"2:05","i":"Press down slowly and gently for ~30 seconds."},{"t":"2:30","i":"Stop at hiss. Serve immediately."}],"notes":["Key: less coffee (11g), more water (200g), finer grind = sweet, clean, balanced cup."]},
"Moka Pot (Stovetop Espresso)":{"cat":"Moka & Espresso","device":"Moka Pot (Bialetti or similar)","grind":"Fine (slightly coarser than espresso)","dose":"15-20 (fill basket)","water":"~200-300 (basket-dependent)","ratio":"Basket-fill method (~1:10)","tempC":"Near boiling (~95-100)","time":"5:00 - 7:00","filter":"Built-in metal filter basket","diff":"2","cups":"2-4 (demitasse)","flavor":"Bold, strong, espresso-like intensity; slightly smoky","body":"Very Full","clarity":"Low","bestFor":"Espresso lovers without a machine; Italian tradition","beans":["Italian Espresso Blend","Brazilian Cerrado","Colombian Supremo","Ethiopian Guji"],"steps":[{"t":"Prep","i":"Boil water in a kettle first (using pre-heated water reduces bitter extraction)"},{"t":"Step 1","i":"Fill bottom chamber with hot water to just BELOW the safety valve"},{"t":"Step 2","i":"Fill filter basket with fine-ground coffee; level off without tamping"},{"t":"Step 3","i":"Assemble Moka pot; use a towel to hold hot bottom chamber"},{"t":"Step 4","i":"Place on stove at LOW to MEDIUM heat; leave lid open to watch"},{"t":"Step 5","i":"Coffee begins to flow into upper chamber; should be honey-colored stream"},{"t":"Step 6","i":"When sputtering/gurgling starts, remove immediately from heat"},{"t":"Step 7","i":"Cool bottom chamber under cold running water to stop extraction"},{"t":"Step 8","i":"Serve immediately; can dilute or add steamed milk"}],"notes":["If coffee is bitter: heat was too high or extraction went too long","If coffee is sour: grind finer or use slightly more heat"]},
"Espresso (Machine)":{"cat":"Moka & Espresso","device":"Espresso machine (pump-driven)","grind":"Very Fine (powdery, like flour)","dose":"18-20 (double shot)","water":"36-40 (double shot output)","ratio":"1:2 (input:output by weight)","tempC":"90-96","time":"0:25 - 0:35 (shot time)","filter":"Metal portafilter basket","diff":"4","cups":"1 (double shot)","flavor":"Concentrated, intense, complex; crema layer; bold","body":"Very Full","clarity":"Medium","bestFor":"Milk-based drinks; straight espresso enthusiasts","beans":["Italian Espresso Blend","Brazilian Cerrado","Colombian Supremo","Ethiopian Guji"],"steps":[{"t":"Prep","i":"Warm up machine for 15-30 min. Flush group head with water."},{"t":"Step 1","i":"Dose 18-20g of freshly ground coffee into portafilter basket."},{"t":"Step 2","i":"Distribute grounds evenly (WDT tool or tap); tamp level with ~15kg pressure."},{"t":"Step 3","i":"Lock portafilter into group head. Place cup underneath."},{"t":"Step 4","i":"Start extraction; timer begins when pump activates."},{"t":"Step 5","i":"Watch flow: should start as slow drips, then thin steady stream ('mouse tail')."},{"t":"Step 6","i":"Target 36-40g output (for 18-20g dose) in 25-35 seconds."},{"t":"Step 7","i":"Stop shot. Serve immediately."}],"notes":["If too fast/sour: grind finer. If too slow/bitter: grind coarser. Adjust in tiny increments."]},
"Turkish Coffee (Traditional)":{"cat":"Turkish & Specialty","device":"Cezve (Ibrik)","grind":"Extra Fine (powder, finer than espresso)","dose":"7-8","water":"70-80","ratio":"1:10 to 1:12","tempC":"Near boiling (~90-95)","time":"2:00 - 4:00","filter":"None (unfiltered; grounds settle)","diff":"3","cups":"1 (demitasse)","flavor":"Very strong, thick, aromatic; optionally sweet or spiced","body":"Very Full","clarity":"Low","bestFor":"Middle Eastern/Balkan tradition; after-meal ritual","beans":["Turkish Blend (fine ground)","Brazilian Santos","Robusta Blend"],"steps":[{"t":"Step 1","i":"Add 70-80g cold filtered water to cezve (ibrik)."},{"t":"Step 2","i":"Add 7-8g extra-fine coffee (like talcum powder). Add sugar now if desired."},{"t":"Step 3","i":"Stir gently to combine coffee, water, and sugar evenly."},{"t":"Step 4","i":"Place cezve on LOW heat. Do NOT rush — gentle heating is critical."},{"t":"Step 5","i":"Watch for foam to begin forming on the surface (~1:30-2:00)."},{"t":"Step 6","i":"When foam rises near the rim, remove from heat. Let settle 20-30 seconds."},{"t":"Step 7","i":"Return to heat. Let foam rise a SECOND time. Remove from heat."},{"t":"Step 8","i":"Return to heat for a THIRD and final foam rise. Remove from heat."},{"t":"Step 9","i":"Optional: splash 1 tsp cold water to help grounds settle faster."},{"t":"Step 10","i":"Pour slowly into demitasse cup, preserving foam on top. Wait 1-2 min to sip."}],"notes":["Traditional = three foam rises. Never let it reach a full rolling boil."]},
"Turkish Coffee (Specialty / Competition)":{"cat":"Turkish & Specialty","device":"Copper Cezve (handmade, thin-wall)","grind":"Very Fine (between Turkish and espresso)","dose":"7","water":"70","ratio":"1:10","tempC":"Start at 60-70, heat to ~92-95 (single foam rise)","time":"2:00 - 3:30","filter":"None (unfiltered)","diff":"4","cups":"1 (demitasse)","flavor":"Clean for Turkish; sweet, complex; light-medium roast nuances","body":"Full","clarity":"Low-Medium","bestFor":"Specialty coffee enthusiasts; competition-style cezve","beans":["Turkish Blend (fine ground)","Brazilian Santos","Robusta Blend"],"steps":[{"t":"Prep","i":"Use light-medium roast specialty coffee; grind between Turkish and espresso"},{"t":"Step 1","i":"Add 70g of warm water (60-70°C) to copper cezve"},{"t":"Step 2","i":"Add 7g of finely ground coffee on top of the water"},{"t":"Step 3","i":"Stir gently with wooden paddle until coffee is saturated and mixed"},{"t":"Step 4","i":"Place on very low heat (gas flame, sand heater, or micro burner)"},{"t":"Step 5","i":"Watch carefully; foam will begin to form and rise"},{"t":"Step 6","i":"When foam reaches near the rim, remove from heat (SINGLE rise only)"},{"t":"Step 7","i":"Pour slowly into demitasse cup to preserve foam layer on top"},{"t":"Step 8","i":"Wait 1-2 minutes for grounds to settle; sip slowly"}],"notes":["Competition approach: single foam rise (not traditional 3x). No sugar needed with specialty beans."]},
"Siphon (Vacuum Brewer)":{"cat":"Turkish & Specialty","device":"Siphon brewer (Hario, Yama, etc.)","grind":"Medium-Fine (table salt)","dose":"20-25","water":"300-360","ratio":"1:15","tempC":"92-96","time":"2:00 - 3:00","filter":"Cloth or paper siphon filter","diff":"4","cups":"2-3","flavor":"Exceptionally clean, bright, tea-like; theatrical brewing","body":"Light-Medium","clarity":"Very High","bestFor":"Coffee connoisseurs; presentation/showmanship","beans":["Ethiopian Yirgacheffe","Kenyan AA","Guatemalan Antigua"],"steps":[{"t":"Prep","i":"Attach cloth or paper filter to upper chamber; soak cloth if new"},{"t":"Step 1","i":"Add water to lower globe (300-360g); place on heat source"},{"t":"Step 2","i":"As water heats, place upper chamber loosely on top (don't seal yet)"},{"t":"Step 3","i":"When water begins boiling, press upper chamber to create seal"},{"t":"Step 4","i":"Water rises to upper chamber via vacuum pressure"},{"t":"Step 5","i":"Once most water is up top, add ground coffee; stir gently to submerge"},{"t":"Step 6","i":"Let brew for 45-90 seconds in upper chamber"},{"t":"Step 7","i":"Remove from heat; as lower globe cools, vacuum draws brewed coffee down through filter"},{"t":"Step 8","i":"Remove upper chamber; serve from lower globe"}],"notes":["Produces exceptionally clean, bright coffee; visually stunning brewing process"]},
"Vietnamese Phin Filter":{"cat":"World Methods","device":"Vietnamese Phin filter (stainless steel)","grind":"Medium-Coarse to Coarse","dose":"15-25","water":"150-200","ratio":"1:8 to 1:10 (concentrated)","tempC":"95-100","time":"4:00 - 6:00 (slow drip)","filter":"Built-in metal press/filter screen","diff":"1","cups":"1","flavor":"Very strong, dark, robust; traditionally with sweetened condensed milk","body":"Very Full","clarity":"Low","bestFor":"Dark roast lovers; Vietnamese coffee tradition (cà phê sữa đá)","beans":["Colombian Supremo","Brazilian Santos","Sumatra Mandheling","Ethiopian Sidama"],"steps":[{"t":"Prep","i":"Place Phin filter on glass/cup. Add 2-3 tbsp sweetened condensed milk to glass."},{"t":"Step 1","i":"Add coffee grounds to Phin chamber; shake to level."},{"t":"Step 2","i":"Place gravity press/filter screen on top; press gently to compress slightly."},{"t":"Step 3","i":"Add a small splash of hot water (~20g) to bloom the grounds for 20 seconds."},{"t":"Step 4","i":"Fill Phin with remaining hot water to the top."},{"t":"Step 5","i":"Place lid on Phin; wait as coffee slowly drips through (4-6 minutes total)."},{"t":"Step 6","i":"When dripping stops, remove Phin. Stir condensed milk into coffee."},{"t":"Step 7","i":"For iced version: pour over a full glass of ice."}],"notes":["Use dark roast (often Robusta or Robusta/Arabica blend) for authentic flavor."]},
"South Indian Filter Coffee (Kaapi)":{"cat":"World Methods","device":"Stainless steel South Indian coffee filter (dabara set)","grind":"Medium-Fine","dose":"15-30 (2-3 tbsp)","water":"80-150","ratio":"1:10 to 1:15 (decoction)","tempC":"96-100","time":"15-20 min (quick); 3-4 hours (traditional)","filter":"Built-in perforated metal plate + plunger press","diff":"2","cups":"2-3","flavor":"Very strong decoction mixed with boiled milk; rich, creamy, slightly sweet","body":"Full","clarity":"Low","bestFor":"South Indian breakfast; served in tumbler-dabara","beans":["Colombian Supremo","Brazilian Santos","Sumatra Mandheling","Ethiopian Sidama"],"steps":[{"t":"Prep","i":"Ensure South Indian brass/steel coffee filter is clean and dry."},{"t":"Step 1","i":"Add coffee powder (often with 20-30% chicory) to top perforated chamber."},{"t":"Step 2","i":"Gently press down with the plunger disc to level (do NOT compress hard)."},{"t":"Step 3","i":"Pour boiling water (96-100°C) over the grounds; fill top chamber."},{"t":"Step 4","i":"Close with lid; let decoction drip into bottom chamber (15-20 min)."},{"t":"Step 5","i":"Meanwhile, boil full-fat milk in a saucepan."},{"t":"Step 6","i":"Add 2 tbsp strong decoction to tumbler; add boiled milk (ratio to taste, ~1:1 to 1:2)."},{"t":"Step 7","i":"Add sugar to taste. Pour between tumbler and dabara from height to aerate and create froth."}],"notes":["Overnight decoction = thickest, strongest result."]},
"Neapolitan Flip Pot (Napoletana)":{"cat":"World Methods","device":"Neapolitan flip coffee maker (cuccumella)","grind":"Medium-Coarse","dose":"20-30 (fill basket)","water":"300-500","ratio":"Basket-fill (~1:15)","tempC":"100","time":"5:00 - 10:00","filter":"Built-in metal filter basket","diff":"2","cups":"2-4","flavor":"Smooth, medium-bodied, less intense than Moka pot; traditional Neapolitan","body":"Medium","clarity":"Medium","bestFor":"Italian tradition lovers; gentler alternative to Moka pot","beans":["Colombian Supremo","Brazilian Santos","Sumatra Mandheling","Ethiopian Sidama"],"steps":[{"t":"Step 1","i":"Fill bottom water chamber with cold water to just below the steam hole."},{"t":"Step 2","i":"Fill filter basket with medium-coarse coffee. Level off; do not tamp."},{"t":"Step 3","i":"Assemble: water chamber on bottom, filter in middle, empty serving chamber on top."},{"t":"Step 4","i":"Place on stove over medium heat (serving spout points DOWN at this stage)."},{"t":"Step 5","i":"Wait for steam to emerge from the small steam hole near the top."},{"t":"Step 6","i":"When steam appears: remove from heat. FLIP the entire pot upside-down in one confident motion."},{"t":"Step 7","i":"Hot water now gravity-drips through coffee into the serving chamber below."},{"t":"Step 8","i":"Wait 5-8 minutes for all water to drip through. Dripping will slow and stop."},{"t":"Step 9","i":"Remove spent filter basket. Serve from spout."}],"notes":["Produces smoother, gentler coffee than a Moka pot — pure gravity, no steam pressure.","Use oven mitts when flipping! The pot is very hot."]},
"Cowboy Coffee":{"cat":"No-Equipment","device":"Open pot or saucepan over campfire/stove","grind":"Coarse to Very Coarse","dose":"30-60","water":"500-1000","ratio":"1:16 to 1:17","tempC":"100 (full boil, then settle)","time":"4:00 - 5:00","filter":"None (grounds settle)","diff":"1","cups":"2-6","flavor":"Robust, full-bodied, slightly gritty; campfire character","body":"Very Full","clarity":"Very Low","bestFor":"Camping; emergencies; no-equipment situations","beans":["Brazilian Santos","Sumatra Mandheling","Colombian Supremo"],"steps":[{"t":"Step 1","i":"Add water (500-1000g) to a pot or saucepan."},{"t":"Step 2","i":"Bring to a full rolling boil over campfire or stove."},{"t":"Step 3","i":"Remove pot from heat. Wait 30 seconds for boiling to subside."},{"t":"Step 4","i":"Add coarse-ground coffee (30-60g). Stir once gently."},{"t":"Step 5","i":"Cover pot. Let steep for 4-5 minutes off heat."},{"t":"Step 6","i":"Splash ~30ml cold water on top to help grounds settle."},{"t":"Step 7","i":"Wait 2-3 more minutes for grounds to sink."},{"t":"Step 8","i":"Pour carefully from the top into cups, leaving sediment behind in pot."}],"notes":["No filter, no equipment beyond a pot. The original frontier method."]},
"Kopi Tubruk (Indonesian)":{"cat":"No-Equipment","device":"Glass or cup (no special equipment)","grind":"Very Fine (powder, similar to Turkish)","dose":"7-10","water":"150-200","ratio":"1:20 to 1:25","tempC":"100","time":"3:00 - 5:00","filter":"None (grounds settle)","diff":"1","cups":"1","flavor":"Bold, sweet (often with sugar), earthy, full-bodied","body":"Full","clarity":"Very Low","bestFor":"Indonesian daily coffee; simple preparation","beans":["Brazilian Santos","Sumatra Mandheling","Colombian Supremo"],"steps":[{"t":"Step 1","i":"Boil water in a kettle."},{"t":"Step 2","i":"Add 7-10g very finely ground coffee into a cup or glass."},{"t":"Step 3","i":"Add sugar to taste (traditional: 1-2 teaspoons)."},{"t":"Step 4","i":"Pour boiling water directly onto grounds (150-200g)."},{"t":"Step 5","i":"Stir briefly (3-4 times) to dissolve sugar and wet all grounds."},{"t":"Step 6","i":"Wait 3-5 minutes for grounds to settle to the bottom."},{"t":"Step 7","i":"Sip carefully from the top. Do NOT disturb settled grounds."},{"t":"Step 8","i":"Stop drinking when you reach the sludge layer — leave the last ~20ml."}],"notes":["Simplest method: no filter, no device — just cup + coffee + hot water."]},
"Cold Brew (Kyoto Style)":{"cat":"Cold Brew","device":"Kyoto drip tower (Yama, Hario Shizuku, etc.)","grind":"Medium-Coarse (breadcrumbs)","dose":"40-60","water":"600-800 (ice water)","ratio":"1:10 to 1:13","tempC":"Ice cold (0-4)","time":"3-12 hours (1 drip/second)","filter":"Paper disc filter in middle chamber","diff":"3","cups":"4-6 (concentrate)","flavor":"Bright, floral, crystal-clean clarity; nuanced origin flavors","body":"Light-Medium","clarity":"Very High","bestFor":"Coffee connoisseurs; visual spectacle; light roast single origins","beans":["Colombian Supremo","Guatemalan Antigua","Brazilian Santos","Kenyan AA"],"steps":[{"t":"Step 1","i":"Place paper filter disc at bottom of middle coffee chamber."},{"t":"Step 2","i":"Add 40-60g medium-coarse ground coffee; level the bed."},{"t":"Step 3","i":"Place a second wetted paper filter on top of the coffee grounds."},{"t":"Step 4","i":"Fill top water reservoir with ice and cold water (600-800g)."},{"t":"Step 5","i":"Adjust valve to achieve ~1 drip per second (this is critical)."},{"t":"Step 6","i":"Let drip for 3-12 hours depending on tower model and desired strength."},{"t":"Step 7","i":"Collect concentrate in bottom carafe."},{"t":"Step 8","i":"Serve over ice; dilute if needed. Can be stored in fridge for 1-2 weeks."}],"notes":["Produces exceptionally clean, bright, floral cold coffee."]},
"Nitro Cold Brew":{"cat":"Cold Brew","device":"Cold brew system + nitrogen keg/tap","grind":"Coarse (same as cold brew)","dose":"70-100","water":"700-1000","ratio":"1:8 to 1:10 (concentrate base)","tempC":"Room temp steep; served cold (2-5)","time":"12-24 hours + nitrogen infusion","filter":"Fine mesh + paper","diff":"3","cups":"4-8 (from batch)","flavor":"Creamy, velvety, cascading foam; naturally sweet; smooth, low acidity; stout-beer texture","body":"Medium-Full","clarity":"Medium","bestFor":"Craft coffee lovers; dairy-free creaminess; summer refreshment","beans":["Colombian Supremo","Brazilian Santos","Guatemalan Antigua"],"steps":[{"t":"Step 1","i":"Grind 70-100g coffee very coarse (raw sugar texture)."},{"t":"Step 2","i":"Combine with cold/room temp water. Stir to saturate. Cover."},{"t":"Step 3","i":"Refrigerate 18-24 hours (or room temp 12-16 hours)."},{"t":"Step 4","i":"Strain through fine mesh, then paper filter for maximum clarity."},{"t":"Step 5","i":"Transfer cold brew concentrate into a nitrogen-compatible keg or whip cream dispenser."},{"t":"Step 6","i":"Charge with nitrogen (N₂, NOT CO₂ — nitrogen = creamy; CO₂ = fizzy)."},{"t":"Step 7","i":"Shake keg gently. Refrigerate at least 1 hour to let nitrogen absorb."},{"t":"Step 8","i":"Pour via tap or nozzle into glass. The signature cascading micro-bubble effect appears."}],"notes":["Nitrogen creates micro-bubbles = creamy, stout-like mouthfeel without any dairy."]},
"Percolator (Stovetop/Electric)":{"cat":"No-Equipment","device":"Stovetop or electric percolator","grind":"Coarse (chunky, like breadcrumbs)","dose":"40-55","water":"700-1000","ratio":"1:17 to 1:18","tempC":"92-96","time":"7:00 - 10:00","filter":"Metal basket/perforated filter","diff":"1","cups":"4-8","flavor":"Bold, hot, slightly over-extracted; traditional American","body":"Full","clarity":"Low","bestFor":"Camping; nostalgia; those who prefer strong, hot coffee","beans":["Colombian Supremo","Brazilian Santos","Honduran SHG"],"steps":[{"t":"Step 1","i":"Add cold water to bottom chamber of percolator."},{"t":"Step 2","i":"Place filter basket on stem. Add coarse-ground coffee to basket."},{"t":"Step 3","i":"Assemble percolator. Place on heat (or plug in)."},{"t":"Step 4","i":"Water heats, rises through tube, rains over coffee, drips back down and repeats."},{"t":"Step 5","i":"Watch through glass knob on lid: aim for medium-amber color."},{"t":"Step 6","i":"Allow to cycle for 7-10 minutes."},{"t":"Step 7","i":"Remove from heat IMMEDIATELY at desired strength. Over-perking = bitter."},{"t":"Step 8","i":"Let sit 1-2 minutes for grounds to settle, then serve."}],"notes":["Coffee cycles repeatedly through grounds — very easy to over-extract. Time carefully."]},
"Single Serve Pod (Keurig / Nespresso)":{"cat":"No-Equipment","device":"Keurig K-Cup brewer or Nespresso machine","grind":"Pre-ground (sealed in capsule)","dose":"5-7 (K-Cup) / 5-6 (Nespresso)","water":"150-240 (K-Cup) / 25-40 (Nespresso espresso)","ratio":"Pre-set by capsule","tempC":"88-96 (machine-controlled)","time":"0:25 - 1:00","filter":"Capsule/pod built-in filter","diff":"1","cups":"1","flavor":"Convenient, consistent; varies by capsule","body":"Medium (K-Cup) / Full (Nespresso)","clarity":"Medium","bestFor":"Maximum convenience; offices; quick single cups","beans":["Nespresso Compatible Blend","Italian Espresso Blend"],"steps":[{"t":"Step 1","i":"Fill water tank with fresh filtered water if not already full."},{"t":"Step 2","i":"Power on machine. Allow it to heat up (15-60 seconds)."},{"t":"Step 3","i":"Place cup under spout. Select desired volume/size."},{"t":"Step 4","i":"Insert capsule or K-Cup into chamber. Close lever/lid."},{"t":"Step 5","i":"Press brew button. Machine pierces capsule and forces hot water through."},{"t":"Step 6","i":"Nespresso espresso: ~25-40ml in 15-25s. K-Cup: ~150-240ml in 30-60s."},{"t":"Step 7","i":"Remove used capsule. Serve immediately."}],"notes":["Nespresso = ~15-19 bar (espresso-style). Keurig = ~1-2 bar (drip-style).","Refillable capsules let you use freshly ground coffee for much better results.","Drip Coffee Maker (Automatic)"]},
"Drip Coffee Maker (Automatic)":{"cat":"No-Equipment","device":"Automatic drip brewer","grind":"Medium (like beach sand)","dose":"40-60","water":"680-1000","ratio":"1:16 to 1:17","tempC":"92-96","time":"5:00 - 8:00","filter":"Paper basket or cone filter","diff":"1","cups":"4-8","flavor":"Consistent, clean, straightforward; batch brewing convenience","body":"Medium","clarity":"Medium-High","bestFor":"Households; offices; hands-free batch brewing","beans":["Colombian Supremo","Brazilian Santos","Sumatra Mandheling","Ethiopian Sidama"],"steps":[{"t":"Step 1","i":"Fill water reservoir with fresh filtered water to desired cup level."},{"t":"Step 2","i":"Place paper or permanent filter in basket."},{"t":"Step 3","i":"Add medium-ground coffee: ~60g per liter (about 1 tbsp per 6oz cup)."},{"t":"Step 4","i":"Close basket. Press Start/Brew button."},{"t":"Step 5","i":"Machine heats water and drips through coffee bed automatically."},{"t":"Step 6","i":"Brewing completes in 5-8 minutes. Serve from carafe."},{"t":"Step 7","i":"Remove basket/filter to stop dripping onto hot plate."}],"notes":["SCA Gold Cup machines (Technivorm, Breville Precision) maintain optimal 92-96°C."]}};

const CATS = ["Pour Over","AeroPress","Immersion/Hybrid","Immersion","Moka & Espresso","Turkish & Specialty","World Methods","Cold Brew","No-Equipment"];
const CAT_ICONS = {"Pour Over":"☕","AeroPress":"🔵","Immersion/Hybrid":"⚗️","Immersion":"🫙","Moka & Espresso":"☕","Turkish & Specialty":"🫖","World Methods":"🌍","Cold Brew":"🧊","No-Equipment":"🏕️"};
const CAT_COLORS = {"Pour Over":"#c8a97e","AeroPress":"#7eb5c8","Immersion/Hybrid":"#9ec87e","Immersion":"#c87e9e","Moka & Espresso":"#c87e7e","Turkish & Specialty":"#c8b97e","World Methods":"#9e7ec8","Cold Brew":"#7ec8c8","No-Equipment":"#a89070"};
const DIFF_LABEL = ["","Beginner","Easy","Intermediate","Advanced","Expert"];

function parseTimeToSeconds(t) {
  if (!t || t.toLowerCase().includes("hour") || t.toLowerCase().includes("-") && t.length > 10) return 0;
  const clean = t.replace(/[^0-9:]/g, "").trim();
  if (!clean) return 0;
  const parts = clean.split(":");
  if (parts.length === 2) return parseInt(parts[0]||0)*60 + parseInt(parts[1]||0);
  if (parts.length === 1 && parseInt(parts[0]) < 60) return parseInt(parts[0]);
  return 0;
}

function getStepTimer(step) {
  const t = step.t;
  if (!t) return 0;
  // Range like 0:30-2:00 — use first part
  const first = t.split("-")[0].trim();
  return parseTimeToSeconds(first);
}

export default function App() {
  const [screen, setScreen] = useState("home"); // home | methods | technique | beans | brew | done
  const [selectedCat, setSelectedCat] = useState(null);
  const [selectedMethod, setSelectedMethod] = useState(null);
  const [selectedBean, setSelectedBean] = useState(null);
  const [currentStep, setCurrentStep] = useState(0);
  const [timerSec, setTimerSec] = useState(0);
  const [timerRunning, setTimerRunning] = useState(false);
  const [totalElapsed, setTotalElapsed] = useState(0);
  const timerRef = useRef(null);
  const totalRef = useRef(null);

  const method = selectedMethod ? DB[selectedMethod] : null;
  const steps = method ? method.steps : [];

  useEffect(() => {
    if (timerRunning) {
      timerRef.current = setInterval(() => setTimerSec(s => s > 0 ? s - 1 : 0), 1000);
      totalRef.current = setInterval(() => setTotalElapsed(s => s + 1), 1000);
    } else {
      clearInterval(timerRef.current);
      clearInterval(totalRef.current);
    }
    return () => { clearInterval(timerRef.current); clearInterval(totalRef.current); };
  }, [timerRunning]);

  const startStepTimer = useCallback((stepIdx) => {
    clearInterval(timerRef.current);
    const s = getStepTimer(steps[stepIdx]);
    setTimerSec(s);
    setTimerRunning(s > 0);
  }, [steps]);

  const fmt = (s) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2,"0")}`;
  };

  const goHome = () => {
    setScreen("home"); setSelectedCat(null); setSelectedMethod(null); setSelectedBean(null);
    setCurrentStep(0); setTimerSec(0); setTimerRunning(false); setTotalElapsed(0);
  };

  const catMethods = selectedCat ? Object.entries(DB).filter(([,v]) => v.cat === selectedCat) : [];

  // iOS-style status bar color per screen
  const bgCol = screen === "brew" ? "#0a0a0f" : screen === "home" ? "#faf8f4" : "#faf8f4";

  return (
    <div style={{fontFamily:"'Georgia',serif", background: bgCol, minHeight:"100vh", maxWidth:430, margin:"0 auto", position:"relative", userSelect:"none"}}>
      {screen === "home" && <HomeScreen setScreen={setScreen} setSelectedCat={setSelectedCat} />}
      {screen === "methods" && <MethodsScreen cat={selectedCat} methods={catMethods} setScreen={setScreen} setSelectedMethod={setSelectedMethod} goHome={goHome} />}
      {screen === "technique" && method && <TechniqueScreen name={selectedMethod} method={method} setScreen={setScreen} goHome={goHome} />}
      {screen === "beans" && method && <BeansScreen name={selectedMethod} method={method} setScreen={setScreen} setSelectedBean={setSelectedBean} selectedBean={selectedBean} goHome={goHome} />}
      {screen === "brew" && method && <BrewScreen name={selectedMethod} method={method} steps={steps} currentStep={currentStep} setCurrentStep={setCurrentStep} timerSec={timerSec} timerRunning={timerRunning} setTimerRunning={setTimerRunning} totalElapsed={totalElapsed} startStepTimer={startStepTimer} fmt={fmt} setScreen={setScreen} goHome={goHome} />}
      {screen === "done" && <DoneScreen name={selectedMethod} totalElapsed={totalElapsed} fmt={fmt} goHome={goHome} setScreen={setScreen} setCurrentStep={setCurrentStep} startStepTimer={startStepTimer} />}
    </div>
  );
}

function HomeScreen({ setScreen, setSelectedCat }) {
  return (
    <div style={{minHeight:"100vh", background:"#faf8f4"}}>
      {/* Hero */}
      <div style={{background:"linear-gradient(160deg,#1a0f05 0%,#3d200a 60%,#6b3a1f 100%)", padding:"48px 24px 36px", position:"relative", overflow:"hidden"}}>
        <div style={{position:"absolute",top:-40,right:-40,width:200,height:200,borderRadius:"50%",background:"rgba(200,140,60,0.08)"}}/>
        <div style={{position:"absolute",bottom:-20,left:-20,width:120,height:120,borderRadius:"50%",background:"rgba(200,140,60,0.06)"}}/>
        <div style={{position:"relative"}}>
          <div style={{fontSize:48,marginBottom:4}}>☕</div>
          <div style={{color:"#e8d5b0",fontSize:28,fontWeight:"normal",letterSpacing:1,marginBottom:4}}>BrewGuide</div>
          <div style={{color:"#a08060",fontSize:13,letterSpacing:2,textTransform:"uppercase"}}>37 Methods · Perfect Every Cup</div>
        </div>
      </div>
      {/* Category grid */}
      <div style={{padding:"24px 16px"}}>
        <div style={{color:"#3d200a",fontSize:11,letterSpacing:3,textTransform:"uppercase",marginBottom:16,paddingLeft:4}}>Choose a Brewing Method</div>
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:10}}>
          {CATS.map(cat => {
            const count = Object.values(DB).filter(v=>v.cat===cat).length;
            const col = CAT_COLORS[cat];
            return (
              <div key={cat} onClick={()=>{setSelectedCat(cat);setScreen("methods");}} style={{background:"#fff",borderRadius:16,padding:"18px 16px",border:"1px solid #ece6dc",cursor:"pointer",position:"relative",overflow:"hidden",transition:"transform 0.15s",boxShadow:"0 1px 8px rgba(60,30,10,0.06)"}}>
                <div style={{position:"absolute",right:-12,top:-12,width:60,height:60,borderRadius:"50%",background:`${col}18`}}/>
                <div style={{fontSize:24,marginBottom:8}}>{CAT_ICONS[cat]||"☕"}</div>
                <div style={{color:"#1a0f05",fontSize:14,fontWeight:"bold",marginBottom:2,lineHeight:1.3}}>{cat}</div>
                <div style={{color:"#a08060",fontSize:11}}>{count} {count===1?"method":"methods"}</div>
              </div>
            );
          })}
        </div>
        <div style={{marginTop:24,background:"#fff",borderRadius:16,padding:"16px",border:"1px solid #ece6dc",display:"flex",alignItems:"center",gap:12}}>
          <div style={{fontSize:28}}>📖</div>
          <div>
            <div style={{color:"#1a0f05",fontSize:13,fontWeight:"bold"}}>All 37 Methods</div>
            <div style={{color:"#a08060",fontSize:11}}>From V60 to Cowboy Coffee</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function MethodsScreen({ cat, methods, setScreen, setSelectedMethod, goHome }) {
  return (
    <div style={{minHeight:"100vh",background:"#faf8f4"}}>
      <div style={{background:"linear-gradient(135deg,#1a0f05,#3d200a)",padding:"44px 20px 24px",display:"flex",alignItems:"flex-end",justifyContent:"space-between"}}>
        <div>
          <div style={{color:"#a08060",fontSize:11,letterSpacing:2,textTransform:"uppercase",marginBottom:4}}>{CAT_ICONS[cat]} {cat}</div>
          <div style={{color:"#e8d5b0",fontSize:22}}>{methods.length} Techniques</div>
        </div>
        <button onClick={goHome} style={{background:"rgba(255,255,255,0.1)",border:"none",color:"#e8d5b0",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>← Home</button>
      </div>
      <div style={{padding:"16px"}}>
        {methods.map(([name, m]) => (
          <div key={name} onClick={()=>{setSelectedMethod(name);setScreen("technique");}} style={{background:"#fff",borderRadius:16,padding:"16px",marginBottom:10,border:"1px solid #ece6dc",cursor:"pointer",display:"flex",gap:12,alignItems:"flex-start",boxShadow:"0 1px 6px rgba(60,30,10,0.05)"}}>
            <div style={{flex:1}}>
              <div style={{color:"#1a0f05",fontSize:15,fontWeight:"bold",marginBottom:4,lineHeight:1.3}}>{name}</div>
              <div style={{color:"#6b4020",fontSize:12,marginBottom:6,fontStyle:"italic"}}>{m.flavor}</div>
              <div style={{display:"flex",gap:6,flexWrap:"wrap"}}>
                <Pill label={`⏱ ${m.time}`} bg="#f5ede0" col="#6b4020"/>
                <Pill label={`★ ${DIFF_LABEL[parseInt(m.diff)]||m.diff}`} bg="#f5ede0" col="#6b4020"/>
                <Pill label={`${m.dose}g · ${m.water}ml`} bg="#edf5e0" col="#3d6b20"/>
              </div>
            </div>
            <div style={{color:"#c8a060",fontSize:20,marginTop:2}}>›</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function TechniqueScreen({ name, method: m, setScreen, goHome }) {
  return (
    <div style={{minHeight:"100vh",background:"#faf8f4"}}>
      <div style={{background:"linear-gradient(135deg,#1a0f05,#3d200a)",padding:"44px 20px 24px"}}>
        <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",marginBottom:12}}>
          <button onClick={()=>setScreen("methods")} style={{background:"rgba(255,255,255,0.1)",border:"none",color:"#e8d5b0",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>‹ Back</button>
          <button onClick={goHome} style={{background:"rgba(255,255,255,0.1)",border:"none",color:"#e8d5b0",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>⌂</button>
        </div>
        <div style={{color:"#a08060",fontSize:11,letterSpacing:2,textTransform:"uppercase",marginBottom:4}}>{m.cat}</div>
        <div style={{color:"#e8d5b0",fontSize:20,lineHeight:1.3,marginBottom:6}}>{name}</div>
        <div style={{color:"#c8a060",fontSize:13,fontStyle:"italic"}}>{m.flavor}</div>
      </div>
      <div style={{padding:"16px"}}>
        {/* Key specs */}
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:8,marginBottom:14}}>
          {[
            {label:"Coffee",val:`${m.dose}g`},
            {label:"Water",val:`${m.water}ml`},
            {label:"Ratio",val:m.ratio},
            {label:"Temperature",val:`${m.tempC}°C`},
            {label:"Brew Time",val:m.time},
            {label:"Difficulty",val:DIFF_LABEL[parseInt(m.diff)]||m.diff},
          ].map(({label,val})=>(
            <div key={label} style={{background:"#fff",borderRadius:12,padding:"12px 14px",border:"1px solid #ece6dc"}}>
              <div style={{color:"#a08060",fontSize:10,letterSpacing:1.5,textTransform:"uppercase",marginBottom:2}}>{label}</div>
              <div style={{color:"#1a0f05",fontSize:14,fontWeight:"bold"}}>{val}</div>
            </div>
          ))}
        </div>
        {/* Extra info */}
        <div style={{background:"#fff",borderRadius:14,padding:"14px",marginBottom:12,border:"1px solid #ece6dc"}}>
          <Row label="Grind Size" val={m.grind}/>
          <Row label="Filter" val={m.filter}/>
          <Row label="Device" val={m.device}/>
          <Row label="Body" val={m.body}/>
          <Row label="Clarity" val={m.clarity}/>
          <Row label="Best For" val={m.bestFor} last/>
        </div>
        {/* Cups */}
        <div style={{background:"#fff4e6",borderRadius:14,padding:"12px 14px",marginBottom:16,border:"1px solid #f0d9b0"}}>
          <div style={{color:"#6b4020",fontSize:12}}>☕ Yields <strong>{m.cups} cup{m.cups==="1"?"":"s"}</strong></div>
        </div>
        <button onClick={()=>setScreen("beans")} style={{width:"100%",background:"#3d200a",color:"#e8d5b0",border:"none",borderRadius:16,padding:"16px",fontSize:16,cursor:"pointer",letterSpacing:0.5}}>
          Choose Coffee Beans →
        </button>
      </div>
    </div>
  );
}

function BeansScreen({ name, method: m, setScreen, setSelectedBean, selectedBean, goHome }) {
  return (
    <div style={{minHeight:"100vh",background:"#faf8f4"}}>
      <div style={{background:"linear-gradient(135deg,#1a0f05,#3d200a)",padding:"44px 20px 24px"}}>
        <div style={{display:"flex",justifyContent:"space-between",marginBottom:12}}>
          <button onClick={()=>setScreen("technique")} style={{background:"rgba(255,255,255,0.1)",border:"none",color:"#e8d5b0",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>‹ Back</button>
          <button onClick={goHome} style={{background:"rgba(255,255,255,0.1)",border:"none",color:"#e8d5b0",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>⌂</button>
        </div>
        <div style={{color:"#a08060",fontSize:11,letterSpacing:2,textTransform:"uppercase",marginBottom:4}}>Bean Selection</div>
        <div style={{color:"#e8d5b0",fontSize:20,marginBottom:4}}>{name}</div>
        <div style={{color:"#c8a060",fontSize:13}}>Select a bean to continue</div>
      </div>
      <div style={{padding:"16px"}}>
        <div style={{color:"#3d200a",fontSize:11,letterSpacing:2,textTransform:"uppercase",marginBottom:12}}>Recommended Beans</div>
        {m.beans.map(b=>(
          <div key={b} onClick={()=>setSelectedBean(b)} style={{background: selectedBean===b?"#3d200a":"#fff",borderRadius:14,padding:"14px 16px",marginBottom:8,border: selectedBean===b?"1px solid #3d200a":"1px solid #ece6dc",cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"space-between",transition:"all 0.2s",boxShadow: selectedBean===b?"0 2px 12px rgba(60,20,0,0.2)":"0 1px 4px rgba(60,30,10,0.04)"}}>
            <div>
              <div style={{color: selectedBean===b?"#e8d5b0":"#1a0f05",fontSize:15,fontWeight:"bold",marginBottom:2}}>{b}</div>
              <div style={{color: selectedBean===b?"#c8a060":"#a08060",fontSize:12}}>🌱 Single Origin / Blend</div>
            </div>
            <div style={{width:22,height:22,borderRadius:"50%",border: `2px solid ${selectedBean===b?"#c8a060":"#d0c0a0"}`,background: selectedBean===b?"#c8a060":"transparent",display:"flex",alignItems:"center",justifyContent:"center"}}>
              {selectedBean===b && <div style={{width:8,height:8,borderRadius:"50%",background:"#1a0f05"}}/>}
            </div>
          </div>
        ))}
        <div style={{marginTop:8,background:"#f5ede0",borderRadius:14,padding:"14px 16px",marginBottom:16,border:"1px solid #e8d5b0"}}>
          <div style={{color:"#6b4020",fontSize:12,fontWeight:"bold",marginBottom:4}}>Why these beans?</div>
          <div style={{color:"#6b4020",fontSize:12,lineHeight:1.5}}>These are curated for <strong>{m.cat}</strong> brewing — matched to your grind profile (<em>{m.grind}</em>) and flavor target: <em>{m.flavor}</em>.</div>
        </div>
        <button
          onClick={()=>{ if(selectedBean) setScreen("brew"); }}
          style={{width:"100%",background: selectedBean?"#3d200a":"#c0b090",color: selectedBean?"#e8d5b0":"#a09070",border:"none",borderRadius:16,padding:"16px",fontSize:16,cursor: selectedBean?"pointer":"default",letterSpacing:0.5,transition:"all 0.2s"}}
        >
          {selectedBean ? "Start Brewing →" : "Select a Bean to Continue"}
        </button>
      </div>
    </div>
  );
}

function BrewScreen({ name, method: m, steps, currentStep, setCurrentStep, timerSec, timerRunning, setTimerRunning, totalElapsed, startStepTimer, fmt, setScreen, goHome }) {
  const step = steps[currentStep];
  const progress = steps.length > 0 ? (currentStep / steps.length) : 0;
  const isLast = currentStep === steps.length - 1;

  const nextStep = () => {
    if (isLast) { setTimerRunning(false); setScreen("done"); return; }
    const next = currentStep + 1;
    setCurrentStep(next);
    startStepTimer(next);
  };

  const prevStep = () => {
    if (currentStep > 0) {
      const prev = currentStep - 1;
      setCurrentStep(prev);
      startStepTimer(prev);
    }
  };

  const timerColor = timerSec === 0 && timerRunning === false ? "#4a9e4a" : timerSec < 10 && timerSec > 0 ? "#e05040" : "#e8d5b0";

  return (
    <div style={{minHeight:"100vh",background:"#0a0a0f",color:"#e8d5b0",display:"flex",flexDirection:"column"}}>
      {/* Top bar */}
      <div style={{padding:"44px 20px 16px",borderBottom:"1px solid #1e1a14"}}>
        <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",marginBottom:16}}>
          <button onClick={()=>{setTimerRunning(false);setScreen("beans");}} style={{background:"rgba(255,255,255,0.05)",border:"none",color:"#a08060",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>‹ Back</button>
          <div style={{color:"#a08060",fontSize:11,letterSpacing:2,textTransform:"uppercase"}}>Brewing</div>
          <button onClick={()=>{setTimerRunning(false);goHome();}} style={{background:"rgba(255,255,255,0.05)",border:"none",color:"#a08060",padding:"8px 14px",borderRadius:20,fontSize:12,cursor:"pointer"}}>⌂</button>
        </div>
        {/* Progress bar */}
        <div style={{background:"#1e1a14",borderRadius:4,height:4,overflow:"hidden",marginBottom:10}}>
          <div style={{background:"linear-gradient(90deg,#c8a060,#e8d5b0)",height:"100%",width:`${(currentStep+1)/steps.length*100}%`,borderRadius:4,transition:"width 0.4s ease"}}/>
        </div>
        <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
          <div style={{color:"#c8a060",fontSize:13}}>{name.split("–")[0].trim()}</div>
          <div style={{color:"#6b5040",fontSize:12}}>Step {currentStep+1} of {steps.length}</div>
        </div>
      </div>

      {/* Timer area */}
      <div style={{padding:"24px 20px",textAlign:"center",borderBottom:"1px solid #1e1a14"}}>
        <div style={{fontSize:11,color:"#6b5040",letterSpacing:2,textTransform:"uppercase",marginBottom:4}}>
          {step?.t === "Prep" || step?.t === "Done" ? "Prep Step" : step?.t ? `At ${step.t}` : "Timer"}
        </div>
        {timerSec > 0 || timerRunning ? (
          <div>
            <div style={{fontSize:60,fontWeight:"bold",color:timerColor,letterSpacing:2,fontFamily:"monospace"}}>{fmt(timerSec)}</div>
            <div style={{color:"#6b5040",fontSize:11,marginBottom:12}}>Total: {fmt(totalElapsed)}</div>
          </div>
        ) : (
          <div style={{fontSize:32,color:"#4a9e4a",marginBottom:4}}>✓</div>
        )}
        <div style={{display:"flex",gap:10,justifyContent:"center"}}>
          <button onClick={()=>setTimerRunning(r=>!r)} style={{background: timerRunning?"#3d1a0a":"#1a3d0a",border:"none",color: timerRunning?"#e8a060":"#a0e860",padding:"10px 22px",borderRadius:20,fontSize:13,cursor:"pointer"}}>
            {timerRunning ? "⏸ Pause" : "▶ Start"}
          </button>
          <button onClick={()=>{const s=getStepTimer(step);setTimerSec(s);setTimerRunning(s>0);}} style={{background:"#1a1a2a",border:"none",color:"#a08060",padding:"10px 22px",borderRadius:20,fontSize:13,cursor:"pointer"}}>↺ Reset</button>
        </div>
      </div>

      {/* Step instruction */}
      <div style={{flex:1,padding:"20px",overflowY:"auto"}}>
        <div style={{background:"#141018",borderRadius:16,padding:"20px",marginBottom:14,border:"1px solid #2a2020"}}>
          <div style={{color:"#c8a060",fontSize:11,letterSpacing:2,textTransform:"uppercase",marginBottom:8}}>Step {currentStep+1}</div>
          <div style={{color:"#e8d5b0",fontSize:17,lineHeight:1.65}}>{step?.i}</div>
        </div>

        {/* Spec reminder */}
        <div style={{display:"grid",gridTemplateColumns:"1fr 1fr 1fr",gap:6,marginBottom:14}}>
          {[
            {label:"Coffee",val:`${m.dose}g`},
            {label:"Water",val:`${m.water}ml`},
            {label:"Temp",val:`${m.tempC}°C`},
          ].map(({label,val})=>(
            <div key={label} style={{background:"#141018",borderRadius:10,padding:"10px 8px",textAlign:"center",border:"1px solid #2a2020"}}>
              <div style={{color:"#6b5040",fontSize:9,letterSpacing:1.5,textTransform:"uppercase",marginBottom:2}}>{label}</div>
              <div style={{color:"#c8a060",fontSize:12,fontWeight:"bold"}}>{val}</div>
            </div>
          ))}
        </div>

        {/* Notes for this step */}
        {m.notes && m.notes.length > 0 && (
          <div style={{background:"#1a140a",borderRadius:12,padding:"12px 14px",marginBottom:14,border:"1px solid #3a2a10"}}>
            <div style={{color:"#c8a060",fontSize:10,letterSpacing:1.5,textTransform:"uppercase",marginBottom:6}}>Tips</div>
            {m.notes.map((n,i)=>(
              <div key={i} style={{color:"#a08060",fontSize:12,lineHeight:1.5,marginBottom:4}}>💡 {n}</div>
            ))}
          </div>
        )}
      </div>

      {/* Navigation */}
      <div style={{padding:"16px 20px",borderTop:"1px solid #1e1a14",display:"flex",gap:10}}>
        {currentStep > 0 && (
          <button onClick={prevStep} style={{flex:1,background:"#1a1a1a",border:"1px solid #2a2a2a",color:"#a08060",padding:"14px",borderRadius:14,fontSize:14,cursor:"pointer"}}>‹ Previous</button>
        )}
        <button onClick={nextStep} style={{flex:2,background: isLast?"linear-gradient(135deg,#3d8020,#2a5a14)":"linear-gradient(135deg,#6b3a1f,#3d200a)",border:"none",color:"#e8d5b0",padding:"14px",borderRadius:14,fontSize:15,cursor:"pointer",fontWeight:"bold"}}>
          {isLast ? "Finish Brewing ☕" : "Next Step →"}
        </button>
      </div>
    </div>
  );
}

function DoneScreen({ name, totalElapsed, fmt, goHome, setScreen, setCurrentStep, startStepTimer }) {
  return (
    <div style={{minHeight:"100vh",background:"linear-gradient(160deg,#0a0a0f 0%,#1a0f05 40%,#3d200a 100%)",display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",padding:32,textAlign:"center"}}>
      <div style={{fontSize:72,marginBottom:16}}>☕</div>
      <div style={{color:"#e8d5b0",fontSize:26,marginBottom:8}}>Your coffee is ready!</div>
      <div style={{color:"#a08060",fontSize:14,marginBottom:4}}>{name}</div>
      <div style={{color:"#6b5040",fontSize:13,marginBottom:32}}>Brewed in {fmt(totalElapsed)}</div>
      <div style={{background:"rgba(255,255,255,0.04)",borderRadius:16,padding:"16px 24px",marginBottom:28,border:"1px solid #2a2020",width:"100%",maxWidth:300}}>
        <div style={{color:"#c8a060",fontSize:13,marginBottom:8}}>Enjoying it?</div>
        <div style={{color:"#a08060",fontSize:12,lineHeight:1.6}}>Take note of flavor, strength, and extraction. Small grind adjustments make a big difference next time.</div>
      </div>
      <button onClick={goHome} style={{background:"#3d200a",color:"#e8d5b0",border:"none",borderRadius:16,padding:"16px 40px",fontSize:16,cursor:"pointer",width:"100%",maxWidth:300,marginBottom:10}}>
        Brew Another ↺
      </button>
      <button onClick={()=>{setCurrentStep(0);setScreen("brew");}} style={{background:"transparent",color:"#6b5040",border:"1px solid #3a2a10",borderRadius:16,padding:"12px 32px",fontSize:13,cursor:"pointer",width:"100%",maxWidth:300}}>
        Repeat This Recipe
      </button>
    </div>
  );
}

function Pill({ label, bg, col }) {
  return <span style={{background:bg,color:col,fontSize:11,padding:"3px 8px",borderRadius:8}}>{label}</span>;
}

function Row({ label, val, last }) {
  return (
    <div style={{display:"flex",justifyContent:"space-between",alignItems:"flex-start",paddingBottom:last?0:8,marginBottom:last?0:8,borderBottom:last?"none":"1px solid #f0e8dc",gap:12}}>
      <div style={{color:"#a08060",fontSize:11,letterSpacing:1,textTransform:"uppercase",flexShrink:0,paddingTop:1}}>{label}</div>
      <div style={{color:"#1a0f05",fontSize:12,textAlign:"right",lineHeight:1.4}}>{val}</div>
    </div>
  );
}

function getStepTimer(step) {
  if (!step) return 0;
  const t = step.t;
  if (!t) return 0;
  const first = t.split("-")[0].trim();
  const clean = first.replace(/[^0-9:]/g,"").trim();
  if (!clean) return 0;
  const parts = clean.split(":");
  if (parts.length===2) return parseInt(parts[0]||0)*60+parseInt(parts[1]||0);
  if (parts.length===1 && parseInt(parts[0])<60) return parseInt(parts[0]);
  return 0;
}
