# Native companion

A compact workspace switcher, built with AppKit and the existing Bash CLI.
The single-line header identifies Codex Profiles and offers a gear menu.
Native search matches project names, paths and profiles; a profile filter and
ChatGPT/Terminal segmented control sit immediately below it. Pinned projects precede the other
workspaces, which are ordered by last successful launch. Never call an unopened
binding “recent”.

The 400-point popover uses semantic macOS colours, system type, monochrome
SF Symbols and the material supplied by NSPopover. The content view has no
additional effect layer. Plain rows with thin separators show
the project name, profile and path, a small Open button, and workspace actions.
Unavailable rows show a reason and retain their actions. Available rows are
56 points high; an unavailable row adds 16 points for its explanation. Rows
remain unselected on opening and after search changes. Arrow-key selection
uses a subtle system accent fill. Height follows content up to 500 points; longer lists
scroll. Add Workspace sits in the footer; the empty state has one primary Add
Workspace action. App-level setup, sign-in, About and Quit live in the gear menu.

Apple's [menu-bar guidance](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar#Menu-bar-extras)
prefers a menu unless the functionality calls for richer controls. Search,
profile selection and destination switching justify a popover here. Follow the
[popover guidance](https://developer.apple.com/design/human-interface-guidelines/popovers)
for related tasks, anchoring, minimal size and dismissal. The monochrome header,
gear, separators and inline Open actions interpret the user's visual reference;
they are not dimensions or a layout mandated by Apple.

Keyboard: search receives focus on opening; arrows select available projects,
Return launches the selection or the first available match,
Command-1 through Command-9 launch visible rows, Command-K
focuses search, Command-R refreshes, and Escape clears search before closing.
Successful launches dismiss the popover. Failed launches leave the error
visible. Folder pickers and About dismiss the menu before opening; alerts can
remain above it. Dialogs and native menus retain their own keyboard handling.

Workspace actions: pin/unpin, reveal in Finder, copy path, change profile,
locate a moved folder, and remove only the binding. Locating binds the new
folder successfully before removing the old entry. Profile reassignment keeps
pin and recency metadata. The app refreshes when opened, coalesces concurrent
refreshes, and keeps loaded content on refresh failure. The CLI remains the
only writer of profile and binding state; the GUI persists only its pins,
recents and destination preference in UserDefaults.

The app uses NSStatusItem, a transient NSPopover and accessory activation.
The AppKit implementation builds directly with swiftc without runtime dependencies.

Render previews from the actual view in Aqua and Dark Aqua on an opaque
system window background. Offscreen rendering cannot sample the desktop; a
behind-window effect there produces a grey fallback instead of live glass.
The renderer verifies that the exported backdrop matches the system colour,
and both appearances run in the native test suite. These are layout previews;
they do not demonstrate live translucency, system permission prompts or
upstream app behaviour. The AppKit interaction runner checks selection,
search, dismissal and launch arguments against an isolated executable.
