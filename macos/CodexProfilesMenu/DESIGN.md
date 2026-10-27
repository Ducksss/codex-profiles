# Native companion

A compact profile and workspace launcher, built with AppKit and the existing
Bash CLI.
The header is one line: native search and a gear menu. Search matches profile
names, project names and paths. Each profile leads its own group and opens
without a folder; its workspaces sit beneath it, pinned first and then ordered
by last successful launch. Never call an unopened binding “recent”.
Workspaces whose profile is missing follow the groups. A hairline divides
groups; rows within a group have no rules, because the nesting already shows
what belongs together. Nesting and search replace a profile filter.

The 360-point popover uses semantic macOS colours, system type, SF Symbols
and the material supplied by NSPopover. Colour is reserved for two jobs:
profile identity and quota emphasis. The content view has no
additional effect layer. One type scale sets profile names in 13-point
semibold, workspace names in 13-point regular and details in 11-point
secondary text; weight, not size, carries the hierarchy. A profile row is 46
points high: a 26-point tile in the profile's colour holding its initial or
chosen symbol in white, the name above a detail line, and its quota. A workspace row is a single 30-point line starting at
its profile's title column: a pin or folder symbol, the project name and its
path on one baseline. A search result listed without its profile's row starts
under the profile tiles and names its profile instead. A workspace that
cannot open grows to 44 points to explain why on a second line, always shows
its actions and offers Locate… when its folder is missing.
Rows have no Open buttons: clicking a row opens it. The ⋯ actions button
appears with the hover or selection plate, so resting rows stay quiet, and
it stays in the accessibility tree. Right-click and Control-click show the
same actions. Hover and keyboard selection paint an inset, rounded plate.
Rows remain unselected on opening; while searching, the first available match
is selected so Return's target is visible before it is pressed. Arrow-key
selection uses a system accent fill, a semantic outline and an accessibility
selected state. Height follows content up to 500 points; longer lists scroll.
The footer says what Return and Command-Return open, naming the selection, or
reports the latest outcome, beside Add and Refresh buttons. The empty state
replaces search with the app's name and offers Create Profile; creating a
profile makes it immediately available without a folder picker.
Each profile row shows its tightest Codex window: the remaining percentage in
13-point tabular figures with a smaller percent sign, the window's duration
below it, such as “5h left”, and a 20-point ring filled clockwise from the top
with the remaining share. Normal rings use the secondary label colour. At 25%
or less the ring and number turn orange, and at 10% or less red. In light
mode these are darker than systemOrange and systemRed, so a coloured figure
keeps 4.5:1 contrast on the popover and on the hover plate; dark mode uses
lighter tints. The number always carries the value. A low window replaces
the row's destination description with its name and reset countdown. The
profile's actions menu lists every window with its remaining share and reset
clock time, and when it was checked, as disabled information lines.
Tooltips and the row's accessibility label include relative and absolute
reset times, freshness and the Codex CLI sign-in scope. Countdowns stay in
English to match the surrounding text, while clock times follow the user's
locale and 12/24-hour setting. Workspace rows do not repeat account quota.
Only explicitly adding a workspace asks for a folder. App-level setup,
sign-in, the Return destination, Open at Login, Low-quota alerts, Quota in
menu bar, About and Quit live in the gear menu.

Each profile has a colour and a symbol. Until the person chooses, `default`
is graphite and every other profile takes one of seven colours from an FNV-1a
hash of its name, so the colour stays the same on every launch and does not
shift when profiles are added; the symbol is the profile's initial. The
palette of blue, indigo, purple, pink, teal, green, brown and graphite leaves
out red, orange and yellow so they keep meaning low quota, and white symbols
keep 4.5:1 contrast on every colour. Appearance… in a profile's actions
replaces the list with an editor, in place rather than in a second popover so
dismissal and keyboard focus stay with the menu: a 40-point preview with the
profile's name and its CODEX_HOME path from the documented mapping, eight
round colour swatches, and twelve symbols, the initial and eleven SF Symbols.
A choice applies at once and updates the editor in place. Reset restores the
automatic appearance; Done, Return or Escape returns to the list. The chosen
swatch gains a ring and every choice reports its state to accessibility
clients, so a choice never depends on colour alone. A search result listed
without its profile's row shows a small square of the profile's colour beside
its name. The status item stays a monochrome template image.

Apple's [menu-bar guidance](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar#Menu-bar-extras)
prefers a menu unless the functionality calls for richer controls. Search,
nested rows and inline quota justify a popover here. Follow the
[popover guidance](https://developer.apple.com/design/human-interface-guidelines/popovers)
for related tasks, anchoring, minimal size and dismissal. The search-first
header, nested rows, quota rings and hover-revealed actions interpret the
user's visual reference; they are not dimensions or a layout mandated by Apple.

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
Selection uses an outline as well as colour; Increase Contrast draws it in the
full label colour and outlines row marks. Native controls retain focus,
keyboard behaviour and labelled actions for accessibility clients.

Keyboard: search receives focus on opening; arrows select available profiles
or projects. Return launches the selection or the first available match in
the default destination, and Command-Return launches it in the other one, as
Command-click does for a click. Command-1 through Command-9 launch visible
rows, Command-K focuses search, Command-R refreshes, and Escape clears search
before closing.
Successful launches dismiss the popover. Failed launches leave the error
visible. Folder pickers and About dismiss the menu before opening; alerts can
remain above it. Dialogs and native menus retain their own keyboard handling.

Every row's actions open it once in ChatGPT or Terminal without changing the
default destination, which the gear menu's Return opens in sets. Profile actions add a workspace for that profile and offer
optional Codex CLI sign-in. Workspace actions: pin/unpin,
reveal in Finder, copy path, change profile, locate a moved folder, and remove
only the binding. Menus disable inapplicable items explicitly, because NSMenu's
default auto-enabling re-enables any item whose target responds. A row whose
binding is changing shows Updating… and refuses launches and further changes
until the CLI reports the outcome. Locating binds the new
folder successfully before removing the old entry. Profile reassignment keeps
pin and recency metadata. The app refreshes when opened, coalesces concurrent
refreshes, and keeps loaded content on refresh failure. Committed reassignment,
removal and relocation update affected rows before reloading, so a failed
refresh cannot restore an old launch identity. Superseded or removed rows
cannot launch. The CLI remains the only writer of profile and binding state;
the GUI persists only its pins,
recents, destination preference, profile colours and symbols, and its
Low-quota alerts and menu-bar figure choices in UserDefaults. Profile-only launches start
in the home directory, avoiding accidental project-binding inheritance. Explicit
workspace launches pass their folder to the CLI and preserve its guard rules.

Usage reads delegate to the official CLI app-server's
[`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server) method,
using its initialize/initialized handshake. The companion decodes only quota
windows and ignores account identity, plan and credit metadata. A mapped Codex
bucket takes precedence over the legacy response. Missing data stays
unavailable and passed resets never imply a restored quota. The UI retains
launch actions during reads and failures. A refresh dims the previous reading
instead of replacing it with a placeholder. Readings update their rows in
place, so hover, keyboard focus and the VoiceOver cursor survive while they
stream in; only structural changes rebuild the list. A 60-second memory cache and two
concurrent readers bound the cost; an explicit refresh bypasses the cache.
Replies are framed by newline without rescanning buffered bytes, so the 1 MiB
output bound is reached in linear time.
Each reader runs in a private unbound directory, drops inherited credential
override variables and has a ten-second deadline with owned-process cleanup.
Quit waits for cancelled readers to exit. No inference or account-login RPCs
are sent and no quota snapshots are persisted.

The app uses NSStatusItem, a transient NSPopover and accessory activation.
Open at Login uses `SMAppService.mainApp`; a login launch stays in the menu
bar, a launch by the user opens the menu, and reopening the running app shows
it. The AppKit implementation builds directly with swiftc without runtime
dependencies.

The status item reflects low quota from readings the app already holds, so it
needs no permission and starts no reads. When an initialized profile's
constraining window is low or critical and not yet reset, the template icon
gains a badge cut out from the symbol: a solid dot when low, an exclamation
mark cut into it when critical. The 9-point badge and its one-point bar, gap
and dot sit on whole points, so the mark stays legible on 1x displays as well
as Retina. Shape carries the state and the icon stays
monochrome; the tooltip and accessibility label name each profile, window,
remaining percentage and reset clock time, such as
`work: 5h limit at 8%, resets 14:20`. A one-shot timer re-evaluates the icon
at the earliest reset, waiting at most a day so an implausible reset time
cannot overflow it. Remaining quota only falls within a window, so a
reading stays a true upper bound until then.

Quota in menu bar, an opt-in gear-menu toggle that is off by default, adds
the lowest remaining share across initialized profiles beside the icon in
monospaced menu-bar text, such as 7%. Unlike the badge it also covers healthy
windows, and the tooltip and accessibility label then name that profile and
window. The lowest figure can only rise when its own window resets, so the
same one-shot timer re-evaluates it then. While the figure is on, usage is
read about every five minutes through the same refreshUsage path as alerts,
so it stays current; it needs no notification permission. Background reads
stop only when both alerts and the figure are off.

Low-quota alerts is an opt-in gear-menu toggle, off by default so the app
never shows an unrequested permission prompt. Authorization is requested only
when the toggle is turned on; denial keeps it off and explains System
Settings › Notifications. A prompt left unanswered for two minutes is treated
as a denial, so the toggle never stays disabled; allowing notifications later
and choosing the toggle again turns alerts on. Permission revoked later, or
never granted to this copy of the app, shows a mixed state that turns alerts
off when chosen. Notifications announce crossings, never
states: the first settled reading after launch or after enabling is a
baseline, and readings still refreshing or older than the 60-second cache are
left out of it. A reset period is identified by its reset time: readings
whose reset times lie within 60 seconds of each other share a period, so
jitter neither repeats nor invents a crossing, and a different reset time,
including an early reset, starts a new period. Each profile window notifies
at most once per level and reset period, and a profile
gets one notification per reading. A window without a reported reset time
re-arms a level only after climbing more than five points above its
threshold (over 30% for low, over 15% for critical), so a reading hovering at
a threshold cannot repeat. A later critical notification replaces
the low one for the same window. The body names the reset time and mentions
another profile only when it has at least 50% of the same window left, no
low window of its own and a reading under 15 minutes old. Clicking a
notification opens the popover. While alerts are on, a five-minute loop with
timer tolerance calls the same refreshUsage path, so the cache, two readers,
deadlines and owned-process cleanup are unchanged; turning alerts off or
Quit stops it, and no reader starts without initialized profiles. The app
never switches profiles or accounts automatically: alerts show the numbers
and the person chooses. The decision logic is plain Foundation behind a
notifier protocol, so tests never touch UNUserNotificationCenter.

Render previews from the actual view in Aqua and Dark Aqua on an opaque
system window background. Offscreen rendering cannot sample the desktop; a
behind-window effect there produces a grey fallback instead of live glass.
The renderer verifies that the exported backdrop matches the system colour,
and both appearances run in the native test suite. Quota numbers are sample
values. These are layout previews;
they do not demonstrate live translucency, system permission prompts or
upstream app behaviour. Previews render at 2x whatever display draws them. The
AppKit interaction runner checks profile-first setup, nesting and alignment,
automatic and chosen profile appearance, the appearance editor and its
persistence, the menu-bar figure toggle, selection, search, dismissal, Command-Return, the Return destination and
launch arguments against an isolated executable. It switches the same open view light → dark → light, checks
system-colour and accessibility notifications, and verifies opaque selection
policies and accessibility state. These checks do not change global OS
preferences. Actual preference toggles, VoiceOver announcements and live
popover glass require a manual macOS check.
Quota checks cover the official wire contract, multiple buckets, nullable
windows, exhaustion, expired resets, caching, concurrency, malformed replies,
timeouts and cancellation. The interaction runner also checks in-place usage
updates, refresh dimming, quota colours in both appearances, the usage lines
in profile actions, rows being changed, right-click actions, menu enablement after AppKit
validation, one-off destinations and Open at Login through a fake login item. An isolated real CLI integration verifies profile
selection and strict workspace-guard handling with a fake app-server.
Alert checks cover indicator state and its bounded timer, the lowest
figure and its tooltip, background reads that follow the figure, crossing and
de-duplication across jitter, early resets and missing reset times, the
settled baseline after enabling, headroom choice, preference persistence,
permission denial, undecided and unanswered prompts, background reads that
follow the toggle and the badge shapes at 1x and 2x, using a fake notifier.
Real banners and permission prompts require a manual macOS check.
