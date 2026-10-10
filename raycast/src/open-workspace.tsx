import { Action, ActionPanel, Color, Icon, Keyboard, List } from "@raycast/api";
import { useCachedPromise, useFrecencySorting } from "@raycast/utils";
import { useRef, useState } from "react";
import { HOME, loadWorkspaces } from "./cli";
import { bindingProblem, displayPath, folderName, type WorkspaceBinding } from "./lib/profile";
import { shellQuote } from "./lib/terminal";
import { CliGate, LaunchActions } from "./shared";

const ALL_PROFILES = "";

export default function Command() {
  return <CliGate searchBarPlaceholder="Search workspaces">{(cli) => <WorkspaceList cli={cli} />}</CliGate>;
}

function WorkspaceList(props: { cli: string }) {
  const { cli } = props;
  const [profileFilter, setProfileFilter] = useState(ALL_PROFILES);
  const abortable = useRef<AbortController>(null);
  const { data, isLoading, error, revalidate } = useCachedPromise(
    (path: string) => loadWorkspaces(path, abortable.current?.signal),
    [cli],
    { keepPreviousData: true, abortable, failureToastOptions: { title: "Could not load workspaces" } },
  );
  const bindings = data?.bindings ?? [];
  const { data: sorted, visitItem } = useFrecencySorting(bindings, {
    namespace: "workspaces",
    key: (binding) => binding.path,
  });
  const profiles = [...new Set(bindings.map((binding) => binding.profile))].sort((a, b) => a.localeCompare(b));
  const visible = sorted.filter((binding) => profileFilter === ALL_PROFILES || binding.profile === profileFilter);

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Search workspaces"
      searchBarAccessory={
        profiles.length > 1 ? (
          <List.Dropdown tooltip="Filter by profile" value={profileFilter} onChange={setProfileFilter}>
            <List.Dropdown.Item title="All Profiles" value={ALL_PROFILES} />
            <List.Dropdown.Section>
              {profiles.map((profile) => (
                <List.Dropdown.Item key={profile} title={profile} value={profile} />
              ))}
            </List.Dropdown.Section>
          </List.Dropdown>
        ) : undefined
      }
    >
      {isLoading ? null : error && !data ? (
        <List.EmptyView
          icon={Icon.Warning}
          title="Could not load workspaces"
          description={error.message}
          actions={
            <ActionPanel>
              <Action title="Try Again" icon={Icon.ArrowClockwise} onAction={revalidate} />
              <Action.CopyToClipboard title="Copy Error" content={error.message} />
            </ActionPanel>
          }
        />
      ) : (
        <List.EmptyView
          icon={Icon.Folder}
          title="No workspace bindings"
          description="Bind a project folder to a profile with codex-profile workspace bind <path> <profile>."
          actions={
            <ActionPanel>
              <Action.CopyToClipboard title="Copy Bind Command" content="codex-profile workspace bind . work" />
              <Action title="Refresh" icon={Icon.ArrowClockwise} onAction={revalidate} />
            </ActionPanel>
          }
        />
      )}
      {visible.length > 0 ? (
        <List.Section title="Workspaces" subtitle={data ? `Guard mode: ${data.guardMode}` : undefined}>
          {visible.map((binding) => (
            <WorkspaceItem
              key={binding.path}
              cli={cli}
              binding={binding}
              onLaunch={() => visitItem(binding)}
              onRefresh={revalidate}
            />
          ))}
        </List.Section>
      ) : null}
    </List>
  );
}

function WorkspaceItem(props: { cli: string; binding: WorkspaceBinding; onLaunch: () => void; onRefresh: () => void }) {
  const { cli, binding } = props;
  const problem = bindingProblem(binding);
  const accessories: List.Item.Accessory[] = [];
  if (problem) accessories.push({ tag: { value: problem, color: Color.Red }, icon: Icon.ExclamationMark });
  accessories.push({ tag: binding.profile, icon: Icon.Person, tooltip: `Bound to profile ${binding.profile}` });

  return (
    <List.Item
      icon={binding.pathExists ? { fileIcon: binding.path } : Icon.Folder}
      title={folderName(binding.path)}
      subtitle={displayPath(binding.path, HOME)}
      keywords={[binding.profile, binding.path]}
      accessories={accessories}
      actions={
        <ActionPanel title={folderName(binding.path)}>
          {problem ? null : (
            <LaunchActions cli={cli} profile={binding.profile} workspace={binding.path} onLaunch={props.onLaunch} />
          )}
          <ActionPanel.Section>
            {binding.pathExists ? (
              <Action.ShowInFinder path={binding.path} shortcut={{ modifiers: ["cmd", "shift"], key: "f" }} />
            ) : null}
            <Action.CopyToClipboard
              title="Copy Folder Path"
              content={binding.path}
              shortcut={Keyboard.Shortcut.Common.CopyPath}
            />
            {problem ? (
              <Action.CopyToClipboard
                title="Copy Unbind Command"
                content={`codex-profile workspace unbind ${shellQuote(binding.path)}`}
              />
            ) : null}
          </ActionPanel.Section>
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
