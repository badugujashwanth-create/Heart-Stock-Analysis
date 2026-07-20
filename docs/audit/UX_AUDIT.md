# UX and accessibility audit

Browser: Playwright bundled Chromium. Viewports: 1280×720 and 390×844.

1. **Initial clarity:** the original screen opened directly on a long “Stroke Risk” form with no visible model boundary. Fixed with an educational title and prominent synthetic/non-medical notice.
2. **Time to value:** 17 empty inputs made the first success path slow. Fixed with a deterministic one-click synthetic example and reset action.
3. **Information hierarchy:** the original form was an uninterrupted field stack. Fixed by grouping profile, health-indicator, and lifestyle inputs inside the existing Material system.
4. **Claim safety:** “probability,” “Critical,” and “triage support” overstated the heuristic. Replaced with score/band language throughout UI, PDF, API metadata, and docs.
5. **Navigation:** desktop rail and mobile bottom navigation were retained; all five destinations work in the verified flow.
6. **Responsive layout:** both reference and final builds have zero horizontal overflow at 390px. Final evidence is stored beside this report.
7. **Accessibility:** Flutter semantics expose navigation, buttons, sliders, fields, and major content to Chromium automation. Physical mobile assistive-technology testing remains open.
8. **Data safety:** visible synthetic-only guidance and default-off persistence reduce accidental retention; authentication remains a public-deployment gate.

The current and final screenshots were compared together at matching viewports. The final design preserves the existing light Material palette, typography, cards, icons, radii, and navigation model.
