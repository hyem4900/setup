---
name: hm-front-design-lite
argument-hint: "[다듬을 화면이나 컴포넌트]"
description: A light version of hm's design rules for polishing an existing web screen or component in place, in one file and with no 시안, options, recipes, DESIGN.md, CSS kit or audit scripts. A minimal white, grey and ink look, four type sizes, spacing that shows grouping, 1px borders instead of shadows, honest states, no layout jumps, short copy without filler. Use when the user says "디자인 다듬어", "화면 다듬어", "UI 정리해", "polish this screen", "hm-front-design-lite", or asks to tidy the look of a screen they already have.
---

# hm-front-design-lite

Polish what exists; do not redesign. One file, no references: everything needed is below.

## Scope
- Change only the screen, component or style that was named, and only its look, spacing, states and copy. No new features, no new screens, no new libraries, no CSS kit copied in.
- The project's own design system wins (tokens, a UI kit, a DESIGN.md, an existing component library). Use its tokens, classes and components; these rules fill only what it leaves open.
- Keep behaviour, data and markup structure unless a rule below needs a small change (a `div` that acts as a button becomes a `button`).

## Workflow
1. Read only the files of the named screen and the stylesheet or tokens they use. Do not scan the whole project.
2. List the problems against the rules below, worst first, at most 10. Fix them in place with the smallest diff, reusing what is there.
3. Check: phone width (320px, no horizontal scroll), keyboard (Tab order, visible focus), contrast. If a browser or screenshot tool is at hand, look once after the change; otherwise say it was not looked at.
4. Report in three to six lines: what changed and why, and what was left (a rule that needs a bigger change).

## Tokens (only when the project has none)
Add one small block to the global stylesheet and use it; never hard-code these values in components.
```css
:root{--bg:#fff;--surface:#f1f3f5;--line:#e9ecef;--border:#dee2e6;--text-strong:#191919;--text:#343a40;--text-muted:#687077;
--accent:#191919;--on-accent:#fff;--error:#c92a2a;--warning:#b15b00;--success:#28823a;
--r-sm:6px;--r-md:8px;--r-lg:12px;--t:150ms;--ease:cubic-bezier(.2,0,0,1)}
:root[data-theme="dark"]{--bg:#121314;--surface:#26282b;--line:#2c2e31;--border:#3a3d41;--text-strong:#f1f3f5;--text:#dee2e6;
--text-muted:#878f97;--accent:#f1f3f5;--on-accent:#121314;--error:#ff8787;--warning:#ffa94d;--success:#69db7c}
```
Spacing scale 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48. Control heights 32 · 40 · 48. Type 12 · 14 · 16 · 22.

## Look
- Minimal: white, grey and ink. Colour only where it has a job: the main action, links, status, and things the user must tell apart (muted category colours, the same colour for the same thing everywhere).
- Areas are separated by space and 1px borders. No decorative shadows, gradients or thick borders. Only layers floating over content (menus, popovers, dialogs, toasts) get a shadow.
- No accent stripe on one edge of a box (no one-sided coloured or thicker border, no inset shadow doing the same). A category shows as a dot, a tag or a tinted fill; emphasis as weight.
- Four type sizes (12 · 14 · 16 · 22); hierarchy through weight (400 / 600) and text colour, not more sizes. Hangul line height at least 1.5 (1.6 for paragraphs of three lines or more); 22px headings letter-spacing −0.02em.
- One shape per kind of thing on a screen: one corner radius for controls, one for cards; one button style per role.
- One primary action per screen. Destructive actions stand apart: last in a menu after a divider, in `--error` text, never beside 저장.

## Space and layout
- Space inside a group is always smaller than the space around it, about 1.5× per level: label–field 6, field–field 12, group 32, section 48.
- Reading text and one-column forms at most 720px wide, two-column forms at most 960px; only tables, boards and dashboards take the full width.
- Text edges line up: a text button or icon under a line of text starts on that line's edge, not on its box.
- Phones (700px and below) get their own layout; nothing scrolls sideways except inside a table's own container.

## States and stability
- Every clickable element has hover, press and `:focus-visible` states. Hover and selection never change padding, border width, size or font weight: a border that appears is transparent before; a selected bold label keeps its width.
- Nothing moves after the first frame: images have `width`/`height` or `aspect-ratio`, icons sit in fixed boxes, a loading area is a skeleton of the final size, `html{scrollbar-gutter:stable}`, numbers that change use `font-variant-numeric:tabular-nums`. A web font never swaps in late (`font-display: optional`, or the system font).
- Anything slower than 400ms shows a loading state; a busy button stays the same size.
- Motion only explains (opening, a press, an item arriving or leaving), 120–240ms with `--ease`; never on data changes; off with `prefers-reduced-motion`.
- Empty state: one line of what to do next plus the button that does it. Error: one line plus 다시 시도. Errors stay until closed; success messages leave by themselves.

## Copy
- Short, 합니다체 for results, verbs on buttons (저장, 삭제, 보내기). Korean text `word-break: keep-all`; long URLs `overflow-wrap: anywhere`.
- No filler: no eyebrow labels, slogans, subtitles that restate the title, English doubles, badges for defaults, or the same value said twice.
- Two sentences or more of explanation go behind an info icon (tooltip for 1–2 lines, popover for more). Never hidden: field labels, errors, warnings about irreversible actions, primary button labels.
- Tooltips only for what the user cannot see (cut-off text, an icon-only control); never repeat a visible label; never the native `title`.

## Controls and access
- Touch targets 32–36px with at least 8px between them; no hit area under 24×24px.
- Links go somewhere (`<a href>`), buttons do something (`<button type="button">`); never a click handler on a `div`.
- Text contrast at least 4.5:1 (meta and placeholders too); control edges, focus rings and checkbox rings at least 3:1. Never colour alone: status carries an icon or words.
- Icon-only buttons only for well-known actions (close, search, menu, more, copy), with `aria-label`. Use the project's icon set; without one, Phosphor (regular weight). One icon set per project.
- Forms: visible labels, the error as text under its field after the user left it, the submit button never disabled for invalid input (pressing it shows what is missing), the right `type`, `inputmode` and `autocomplete`, units inside the box.
- Tables: numeric columns right-aligned with tabular numbers, sticky header, cut text ends in an ellipsis with the full value on hover.
- Dialogs close on Esc, trap and return focus; a dialog holding input does not close on a backdrop click.

## Before handing over
The named screen follows every rule above that applies to it, works at 320px and by keyboard alone, nothing shifts on load, hover or press, and every visible line earns its place.
