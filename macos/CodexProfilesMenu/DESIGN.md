# Native companion

A compact profile and workspace switcher, built with AppKit and the existing
Bash CLI.
The single-line header identifies Codex Profiles and offers a gear menu.
Native search matches profile names, project names and paths; a profile filter
and ChatGPT/Terminal segmented control sit immediately below it. Profiles appear
first and open without a folder. Pinned workspaces follow, then other workspaces
ordered by last successful launch. Never call an unopened binding “recent”.

The 400-point popover uses semantic macOS colours, system type, monochrome
SF Symbols and the material supplied by NSPopover. The content view has no
additional effect layer. Plain rows with thin separators show the profile name
or project name and path, a small Open button, and related actions. Profile rows
are 44 points high. Available workspace rows are 56 points high; an unavailable
row adds 16 points for its explanation and retains repair actions. Rows
remain unselected on opening and after search changes. Arrow-key selection
uses a system accent fill, a semantic outline and an accessibility selected
state. Height follows content up to 500 points; longer lists scroll. Optional
Add Workspace sits in the footer. The empty state offers Create Profile;
creating a profile makes it immediately available without a folder picker.
Only explicitly adding a workspace asks for a folder. App-level setup, sign-in,
About and Quit live in the gear menu.

Apple's [menu-bar guidance](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar#Menu-bar-extras)
prefers a menu unless the functionality calls for richer controls. Search,
profile selection and destination switching justify a popover here. Follow the
[popover guidance](https://developer.apple.com/design/human-interface-guidelines/popovers)
for related tasks, anchoring, minimal size and dismissal. The monochrome header,
gear, separators and inline Open actions interpret the user's visual reference;
they are not dimensions or a layout mandated by Apple.

The app never overrides production appearance. The status icon is a template
image; controls, SF Symbols, menus, alerts and NSPopover inherit macOS light,
dark and Auto appearance. Layer colours resolve within the view's effective
appearance and redraw on appearance or system-colour changes, including accent
changes. Follow Apple's [Dark Mode guidance](https://developer.apple.com/documentation/appkit/supporting-dark-mode-in-your-interface)
and [appearance inheritance](https://developer.apple.com/documentation/appkit/choosing-a-specific-appearance-for-your-macos-app).

NSWorkspace accessibility-display notifications update the running app.
[Reduce Motion](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)
disables popover animation. Increase Contrast or Reduce Transparency selects
opaque semantic row fills, while NSPopover owns the system background material.
Selection uses an outline as well as colour. Native controls retain focus,
keyboard behaviour and labelled actions for accessibility clients.

Keyboard: search receives focus on opening; arrows select available profiles
or projects. Return launches the selection or the first available match,
Command-1 through Command-9 launch visible rows, Command-K
focuses search, Command-R refreshes, and Escape clears search before closing.
Successful launches dismiss the popover. Failed launches leave the error
visible. Folder pickers and About dismiss the menu before opening; alerts can
remain above it. Dialogs and native menus retain their own keyboard handling.

Profile actions offer optional Codex CLI sign-in. Workspace actions: pin/unpin,
reveal in Finder, copy path, change profile, locate a moved folder, and remove
only the binding. Locating binds the new
folder successfully before removing the old entry. Profile reassignment keeps
pin and recency metadata. The app refreshes when opened, coalesces concurrent
refreshes, and keeps loaded content on refresh failure. Committed reassignment,
removal and relocation update affected rows before reloading, so a failed
refresh cannot restore an old launch identity. Superseded or removed rows
cannot launch. The CLI remains the only writer of profile and binding state;
the GUI persists only its pins,
recents and destination preference in UserDefaults. Profile-only launches start
in the home directory, avoiding accidental project-binding inheritance. Explicit
workspace launches pass their folder to the CLI and preserve its guard rules.

The app uses NSStatusItem, a transient NSPopover and accessory activation.
The AppKit implementation builds directly with swiftc without runtime dependencies.

Render previews from the actual view in Aqua and Dark Aqua on an opaque
system window background. Offscreen rendering cannot sample the desktop; a
behind-window effect there produces a grey fallback instead of live glass.
The renderer verifies that the exported backdrop matches the system colour,
and both appearances run in the native test suite. These are layout previews;
they do not demonstrate live translucency, system permission prompts or
upstream app behaviour. The AppKit interaction runner checks profile-first
setup, selection, search, dismissal and launch arguments against an isolated
executable. It switches the same open view light → dark → light, checks
system-colour and accessibility notifications, and verifies opaque selection
policies and accessibility state. These checks do not change global OS
preferences. Actual preference toggles, VoiceOver announcements and live
popover glass require a manual macOS check.
