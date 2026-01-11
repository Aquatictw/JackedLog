# Navigation Icon Animations

This directory contains Rive animation files (.riv) for morphing navigation icons.

## Icons Required:
1. `nav_history.riv` - History icon with morph states
2. `nav_plans.riv` - Plans/Calendar icon with morph states
3. `nav_graphs.riv` - Graphs/Insights icon with morph states
4. `nav_notes.riv` - Notes icon with morph states
5. `nav_settings.riv` - Settings icon with morph states

## Animation States:
Each .riv file should have 4 states:
- `idle` - Default unselected state
- `selected` - Active/selected state with subtle animation loop
- `morph_in` - Transition animation when becoming selected
- `morph_out` - Transition animation when deselecting

## Design Guidelines:
- Icons should be 24x24dp at 1x scale
- Use Material Design 3 icon style (rounded, friendly)
- Morphing duration: 300-400ms
- Selected state can have subtle bounce/pulse loop (1-2s)
- Colors will be controlled programmatically via Rive runtime

## Fallback:
If Rive animations not available, system falls back to static Material Icons.
