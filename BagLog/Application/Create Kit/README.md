# Create Kit architecture

Create Kit uses feature-local Model–View architecture. SwiftUI owns presentation
state, `CreateKitStore` coordinates the editor workflow, and value types in
`Domain` own deterministic draft rules.

## Dependency direction

```text
Feature → Presentation → State → Domain
                      ↘ Support
```

- `Feature` composes environment dependencies, navigation, and phase routing.
- `State` owns observable workflow state and coordinates persistence and media
  services through injected protocols.
- `Domain` contains draft values, validation, command mapping, and deterministic
  editing operations. It has no SwiftUI dependency.
- `Presentation` groups views by screen responsibility. Views keep local UI
  state and use bindings for draft edits.
- `Support` contains focus order, local sheet destinations, and transferable
  representations used by the presentation layer.

Keep new business rules in `Domain`, service orchestration in `State`, and
view-only behavior in the narrowest matching `Presentation` folder.
