import { Action, ActionPanel, Color, Icon, Keyboard, List } from "@raycast/api";
import { useCachedPromise, useFrecencySorting } from "@raycast/utils";
import { useRef } from "react";
import { HOME, loadProfiles, type ProfileEntry } from "./cli";
import { displayPath } from "./lib/profile";
import { shellQuote } from "./lib/terminal";
import { offersSignIn, usageHeadline, type ProfileUsage } from "./lib/usage";
import { CliGate, LaunchActions, useNow, useUsage } from "./shared";

export default function Command() {
  return <CliGate searchBarPlaceholder="Search profiles">{(cli) => <ProfileList cli={cli} />}</CliGate>;
}

function ProfileList(props: { cli: string }) {
  const { cli } = props;
  const abortable = useRef<AbortController>(null);
  const profiles = useCachedPromise((path: string) => loadProfiles(path, abortable.current?.signal), [cli], {
    keepPreviousData: true,
    abortable,
    failureToastOptions: { title: "Could not load profiles" },
  });
  // Quota is optional decoration here: failures and older CLIs stay silent.
  const usage = useUsage(cli, { quiet: true });
  const now = useNow();
  const { data: sorted, visitItem } = useFrecencySorting(profiles.data, {
    namespace: "profiles",
    key: (profile) => profile.name,
    sortUnvisited: (a, b) => (a.name === "default" ? -1 : b.name === "default" ? 1 : a.name.localeCompare(b.name)),
  });

  const usageByName = new Map<string, ProfileUsage>();
  if (usage.data?.outcome.kind === "ok") {
    for (const entry of usage.data.outcome.profiles) usageByName.set(entry.name, entry);
  }

  const hasProfiles = (profiles.data?.length ?? 0) > 0;
  const refresh = () => {
    profiles.revalidate();
    usage.refresh();
  };

  return (
    // Quota fills in when it arrives; it never holds back the profile list.
    <List isLoading={profiles.isLoading} searchBarPlaceholder="Search profiles">
      {profiles.isLoading ? null : profiles.error && !hasProfiles ? (
        <List.EmptyView
          icon={Icon.Warning}
          title="Could not load profiles"
          description={profiles.error.message}
          actions={
            <ActionPanel>
              <Action title="Try Again" icon={Icon.ArrowClockwise} onAction={refresh} />
              <Action.CopyToClipboard title="Copy Error" content={profiles.error.message} />
            </ActionPanel>
          }
        />
      ) : (
        <List.EmptyView
          icon={Icon.Person}
          title="No profiles yet"
          description="Create one in Terminal with codex-profile setup work, then come back."
          actions={
            <ActionPanel>
              <Action.CopyToClipboard title="Copy Setup Command" content={`${shellQuote(cli)} setup work`} />
              <Action title="Refresh" icon={Icon.ArrowClockwise} onAction={refresh} />
            </ActionPanel>
          }
        />
      )}
      {sorted.map((profile) => (
        <ProfileItem
          key={profile.name}
          cli={cli}
          profile={profile}
          usage={usageByName.get(profile.name)}
          now={now}
          onLaunch={() => visitItem(profile)}
          onRefresh={refresh}
        />
      ))}
    </List>
  );
}

function ProfileItem(props: {
  cli: string;
  profile: ProfileEntry;
  usage?: ProfileUsage;
  now: number;
  onLaunch: () => void;
  onRefresh: () => void;
}) {
  const { cli, profile, usage, now } = props;
  const accessories: List.Item.Accessory[] = [];
  const headline = usage ? usageHeadline(usage, now) : undefined;
  if (headline) {
    if (headline.tag) {
      const color = headline.level === "critical" ? Color.Red : Color.Orange;
      accessories.push({ tag: { value: headline.tag, color }, tooltip: headline.tooltip });
    }
    accessories.push({ text: headline.text, tooltip: headline.tooltip });
  }

  return (
    <List.Item
      icon={Icon.Person}
      title={profile.name}
      subtitle={profile.home ? displayPath(profile.home, HOME) : undefined}
      accessories={accessories}
      actions={
        <ActionPanel title={profile.name}>
          <LaunchActions
            cli={cli}
            profile={profile.name}
            onLaunch={props.onLaunch}
            order={offersSignIn(usage?.state) ? undefined : ["chatgpt", "terminal"]}
          />
          {profile.home ? (
            <ActionPanel.Section>
              <Action.CopyToClipboard
                title="Copy CODEX_HOME Path"
                content={profile.home}
                shortcut={Keyboard.Shortcut.Common.CopyPath}
              />
              <Action.ShowInFinder path={profile.home} shortcut={{ modifiers: ["cmd", "shift"], key: "f" }} />
            </ActionPanel.Section>
          ) : null}
          <ActionPanel.Section>
            <Action
              title="Refresh"
              icon={Icon.ArrowClockwise}
              shortcut={Keyboard.Shortcut.Common.Refresh}
              onAction={props.onRefresh}
            />
          </ActionPanel.Section>
        </ActionPanel>
      }
    />
  );
}
