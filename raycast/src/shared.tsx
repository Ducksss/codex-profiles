import {
  Action,
  ActionPanel,
  Icon,
  Keyboard,
  List,
  Toast,
  openExtensionPreferences,
  showHUD,
  showToast,
} from "@raycast/api";
import { useCachedPromise, usePromise } from "@raycast/utils";
import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  INSTALL_URL,
  SITE_URL,
  loadUsage,
  openInChatGPT,
  openInTerminal,
  resolveCli,
  signInInTerminal,
  type CliResolution,
} from "./cli";

/** Resolves codex-profile once, then renders children with its path. */
export function CliGate(props: { children: (cli: string) => ReactNode; searchBarPlaceholder?: string }) {
  const { data, isLoading, revalidate } = usePromise(resolveCli, [], {
    failureToastOptions: { title: "Could not look for codex-profile" },
  });
  if (!data || isLoading) {
    return <List isLoading searchBarPlaceholder={props.searchBarPlaceholder} />;
  }
  if (data.kind !== "found") {
    return <CliUnavailableView resolution={data} onRetry={revalidate} />;
  }
  return <>{props.children(data.path)}</>;
}

function CliUnavailableView(props: { resolution: Exclude<CliResolution, { kind: "found" }>; onRetry: () => void }) {
  const invalidPath = props.resolution.kind === "invalid-preference" ? props.resolution.path : undefined;
  const invalid = invalidPath !== undefined;
  return (
    <List>
      <List.EmptyView
        icon={Icon.Terminal}
        title={invalid ? "The codex-profile path in preferences isn’t usable" : "codex-profile isn’t installed"}
        description={
          invalid
            ? `${invalidPath} is not an executable file. Fix the path in the extension preferences, or clear it to search the usual locations.`
            : "Install codex-profile (for example with npm install -g codex-profile), or set its full path in the extension preferences."
        }
        actions={
          <ActionPanel>
            {invalid ? (
              <Action title="Open Extension Preferences" icon={Icon.Gear} onAction={openExtensionPreferences} />
            ) : (
              <Action.OpenInBrowser title="Open Install Guide" url={INSTALL_URL} />
            )}
            <Action.CopyToClipboard title="Copy Install Command" content="npm install -g codex-profile" />
            <Action.OpenInBrowser title="Open Project Site" url={SITE_URL} />
            {invalid ? (
              <Action.OpenInBrowser title="Open Install Guide" url={INSTALL_URL} />
            ) : (
              <Action title="Open Extension Preferences" icon={Icon.Gear} onAction={openExtensionPreferences} />
            )}
            <Action
              title="Search Again"
              icon={Icon.ArrowClockwise}
              shortcut={Keyboard.Shortcut.Common.Refresh}
              onAction={props.onRetry}
            />
          </ActionPanel>
        }
      />
    </List>
  );
}

/** Re-renders periodically so countdowns stay current while the view is open. */
export function useNow(intervalMs = 30_000): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(timer);
  }, [intervalMs]);
  return now;
}

/**
 * The latest `usage --json` reading. Cached readings appear immediately; a
 * fresh read only runs when the reading is over a minute old or on Refresh.
 */
export function useUsage(cli: string, options: { quiet?: boolean } = {}) {
  const force = useRef(false);
  const abortable = useRef<AbortController>(null);
  const state = useCachedPromise(
    (path: string) => {
      const forced = force.current;
      force.current = false;
      return loadUsage(path, { force: forced, signal: abortable.current?.signal });
    },
    [cli],
    {
      keepPreviousData: true,
      abortable,
      ...(options.quiet
        ? { onError: () => undefined }
        : { failureToastOptions: { title: "Could not read Codex usage" } }),
    },
  );
  const refresh = () => {
    force.current = true;
    state.revalidate();
  };
  return { ...state, refresh };
}

async function runLaunch(progress: string, success: string, failure: string, work: () => Promise<void>) {
  const toast = await showToast({ style: Toast.Style.Animated, title: progress });
  try {
    await work();
    await toast.hide();
    await showHUD(success);
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = failure;
    toast.message = error instanceof Error ? error.message : String(error);
  }
}

export function launchChatGPT(cli: string, profile: string, workspace?: string) {
  const target = workspace ? `${folderLabel(workspace)} with ${profile}` : profile;
  return runLaunch(`Opening ${target} in ChatGPT…`, `Opened ${target} in ChatGPT`, `Could not open ${target}`, () =>
    openInChatGPT(cli, profile, workspace),
  );
}

export function launchTerminal(cli: string, profile: string, workspace?: string) {
  const target = workspace ? `${folderLabel(workspace)} with ${profile}` : profile;
  return runLaunch(
    `Opening Codex CLI for ${target}…`,
    `Opened Codex CLI for ${target} in Terminal`,
    "Could not open Terminal",
    () => openInTerminal(cli, profile, workspace),
  );
}

export function launchSignIn(cli: string, profile: string) {
  return runLaunch(
    `Opening Codex CLI sign-in for ${profile}…`,
    `Finish signing in to ${profile} in Terminal`,
    "Could not open Terminal",
    () => signInInTerminal(cli, profile),
  );
}

function folderLabel(path: string): string {
  const parts = path.split("/").filter(Boolean);
  return parts.length > 0 ? parts[parts.length - 1] : path;
}

type LaunchKind = "chatgpt" | "terminal" | "sign-in";

const EXTRA_SHORTCUTS: Record<LaunchKind, Keyboard.Shortcut> = {
  chatgpt: { modifiers: ["cmd", "shift"], key: "o" },
  terminal: { modifiers: ["cmd", "shift"], key: "t" },
  "sign-in": { modifiers: ["cmd", "shift"], key: "l" },
};

/**
 * Open in ChatGPT, Open Codex CLI in Terminal and Sign in to Codex CLI, in
 * the given order. The first two take Return and Command-Return; later ones
 * get their own shortcut.
 */
export function LaunchActions(props: {
  cli: string;
  profile: string;
  workspace?: string;
  onLaunch?: () => void;
  order?: LaunchKind[];
}) {
  const { cli, profile, workspace, onLaunch } = props;
  const order = props.order ?? ["chatgpt", "terminal", "sign-in"];
  const actions = order.map((kind, index) => {
    const shortcut = index >= 2 ? EXTRA_SHORTCUTS[kind] : undefined;
    switch (kind) {
      case "chatgpt":
        return (
          <Action
            key={kind}
            title="Open in ChatGPT"
            icon={Icon.Window}
            shortcut={shortcut}
            onAction={() => {
              onLaunch?.();
              return launchChatGPT(cli, profile, workspace);
            }}
          />
        );
      case "terminal":
        return (
          <Action
            key={kind}
            title="Open Codex CLI in Terminal"
            icon={Icon.Terminal}
            shortcut={shortcut}
            onAction={() => {
              onLaunch?.();
              return launchTerminal(cli, profile, workspace);
            }}
          />
        );
      default:
        return (
          <Action
            key={kind}
            title="Sign in to Codex CLI"
            icon={Icon.Key}
            shortcut={shortcut}
            onAction={() => launchSignIn(cli, profile)}
          />
        );
    }
  });
  return <ActionPanel.Section>{actions}</ActionPanel.Section>;
}
