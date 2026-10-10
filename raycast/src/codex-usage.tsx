import { Action, ActionPanel, Color, Icon, Keyboard, List } from "@raycast/api";
import { getProgressIcon } from "@raycast/utils";
import type { ReactNode } from "react";
import { UPGRADE_URL } from "./cli";
import { shellQuote } from "./lib/terminal";
import {
  describeWindow,
  formatResetClock,
  levelLabel,
  stateTitle,
  type ProfileUsage,
  type QuotaLevel,
  type UsageWindow,
} from "./lib/usage";
import { CliGate, LaunchActions, useNow, useUsage } from "./shared";

const UPGRADE_COMMANDS = [
  "Source or standalone install: codex-profile upgrade",
  "npm: npm install -g codex-profile@latest",
  "Homebrew: brew upgrade codex-profile",
].join("\n");

export default function Command() {
  return <CliGate searchBarPlaceholder="Filter profiles">{(cli) => <UsageList cli={cli} />}</CliGate>;
}

function levelColor(level: QuotaLevel): Color {
  if (level === "critical") return Color.Red;
  if (level === "low") return Color.Orange;
  return Color.Green;
}

function UsageList(props: { cli: string }) {
  const { cli } = props;
  const { data, isLoading, error, refresh } = useUsage(cli);
  const now = useNow();
  const outcome = data?.outcome;
  const checked = data ? `Checked ${formatResetClock(data.checkedAt / 1000, now)}` : undefined;
  const refreshAction = (
    <Action title="Refresh" icon={Icon.ArrowClockwise} shortcut={Keyboard.Shortcut.Common.Refresh} onAction={refresh} />
  );

  if (outcome?.kind === "unsupported") {
    return (
      <List isLoading={isLoading}>
        <List.EmptyView
          icon={Icon.ArrowUpCircle}
          title="Codex usage needs a newer codex-profile"
          description={`This codex-profile does not have the usage command yet. Update it, then refresh.\n\n${UPGRADE_COMMANDS}`}
          actions={
            <ActionPanel>
              <Action.CopyToClipboard title="Copy Upgrade Command" content="codex-profile upgrade" />
              <Action.CopyToClipboard title="Copy npm Upgrade Command" content="npm install -g codex-profile@latest" />
              <Action.CopyToClipboard title="Copy Homebrew Upgrade Command" content="brew upgrade codex-profile" />
              <Action.OpenInBrowser title="Open Upgrade Guide" url={UPGRADE_URL} />
              {refreshAction}
            </ActionPanel>
          }
        />
      </List>
    );
  }

  const profiles = outcome?.kind === "ok" ? outcome.profiles : [];

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Filter profiles">
      {isLoading ? null : error && !data ? (
        <List.EmptyView
          icon={Icon.Warning}
          title="Could not read Codex usage"
          description={error.message}
          actions={
            <ActionPanel>
              {refreshAction}
              <Action.CopyToClipboard title="Copy Error" content={error.message} />
            </ActionPanel>
          }
        />
      ) : (
        <List.EmptyView
          icon={Icon.Gauge}
          title="No profiles to show"
          description="Create a profile with codex-profile setup work, sign in to Codex CLI, then refresh."
          actions={<ActionPanel>{refreshAction}</ActionPanel>}
        />
      )}
      {profiles.map((profile, index) => (
        <List.Section key={profile.name} title={profile.name} subtitle={index === 0 ? checked : undefined}>
          <ProfileRows cli={cli} profile={profile} now={now} refreshAction={refreshAction} />
        </List.Section>
      ))}
    </List>
  );
}

function ProfileRows(props: { cli: string; profile: ProfileUsage; now: number; refreshAction: ReactNode }) {
  const { cli, profile, now, refreshAction } = props;
  const keywords = [profile.name];

  if (profile.state === "ok" && profile.windows.length > 0) {
    return (
      <>
        {profile.windows.map((window, index) => (
          <WindowItem
            key={`${profile.name}-${index}`}
            cli={cli}
            profile={profile}
            window={window}
            index={index}
            now={now}
            refreshAction={refreshAction}
          />
        ))}
      </>
    );
  }

  if (profile.state === "ok") {
    return (
      <List.Item
        icon={Icon.Gauge}
        title="No Codex quota windows reported"
        subtitle="This account may not have ChatGPT-backed Codex limits"
        keywords={keywords}
        actions={
          <ActionPanel>
            <LaunchActions cli={cli} profile={profile.name} />
            {refreshAction}
          </ActionPanel>
        }
      />
    );
  }

  if (profile.state === "not_initialized") {
    return (
      <List.Item
        icon={Icon.Person}
        title={stateTitle(profile.state)}
        subtitle={profile.detail}
        keywords={keywords}
        actions={
          <ActionPanel>
            <Action.CopyToClipboard
              title="Copy Init Command"
              content={`codex-profile init ${shellQuote(profile.name)}`}
            />
            {refreshAction}
          </ActionPanel>
        }
      />
    );
  }

  const notSignedIn = profile.state === "not_logged_in";
  return (
    <List.Item
      icon={notSignedIn ? Icon.Key : profile.state === "error" ? Icon.Warning : Icon.QuestionMarkCircle}
      title={stateTitle(profile.state)}
      subtitle={profile.detail}
      keywords={keywords}
      accessories={notSignedIn ? [{ tag: { value: "Sign in", color: Color.Blue } }] : undefined}
      actions={
        <ActionPanel>
          <LaunchActions
            cli={cli}
            profile={profile.name}
            order={notSignedIn ? ["sign-in", "chatgpt", "terminal"] : ["chatgpt", "terminal", "sign-in"]}
          />
          <ActionPanel.Section>
            {refreshAction}
            {profile.detail ? <Action.CopyToClipboard title="Copy Details" content={profile.detail} /> : null}
          </ActionPanel.Section>
        </ActionPanel>
      }
    />
  );
}

function WindowItem(props: {
  cli: string;
  profile: ProfileUsage;
  window: UsageWindow;
  index: number;
  now: number;
  refreshAction: ReactNode;
}) {
  const { cli, profile, window, index, now, refreshAction } = props;
  const description = describeWindow(window, index, now);
  const label = levelLabel(description.level);
  const accessories: List.Item.Accessory[] = [];
  if (label) {
    accessories.push({
      tag: { value: label, color: levelColor(description.level) },
      tooltip: `${label}: ${window.remainingPercent}% of the ${description.label} limit left`,
    });
  }
  if (window.resetsAt !== null && !description.reset) {
    accessories.push({ text: formatResetClock(window.resetsAt, now), tooltip: "Reset time" });
  }

  return (
    <List.Item
      icon={
        description.reset
          ? Icon.Clock
          : getProgressIcon(window.remainingPercent / 100, levelColor(description.level), {
              background: Color.SecondaryText,
            })
      }
      title={description.title}
      subtitle={description.reset ? "Refresh to read it again" : description.subtitle}
      keywords={[profile.name, description.label]}
      accessories={accessories}
      actions={
        <ActionPanel title={profile.name}>
          <LaunchActions cli={cli} profile={profile.name} />
          <ActionPanel.Section>
            {refreshAction}
            <Action.CopyToClipboard
              title="Copy Reading"
              content={`${profile.name} ${description.summary}`}
              shortcut={Keyboard.Shortcut.Common.Copy}
            />
          </ActionPanel.Section>
        </ActionPanel>
      }
    />
  );
}
