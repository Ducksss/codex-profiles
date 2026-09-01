\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
  CREATE ROLE outreach_tracker NOLOGIN;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

CREATE SCHEMA IF NOT EXISTS outreach_private;
REVOKE ALL ON SCHEMA outreach_private FROM PUBLIC;
REVOKE ALL ON SCHEMA outreach_private FROM outreach_tracker;

CREATE TABLE IF NOT EXISTS public.targets (
  key text PRIMARY KEY,
  name text,
  channel text CHECK (channel IS NULL OR channel = ANY (ARRAY[
    'Directory', 'Awesome-List PR', 'Issue-First', 'Forum', 'Owned Listing',
    'Social', 'Manual/Gated', 'Web', 'Mobile', 'Social Media', 'News',
    'E-commerce', 'Podcast', 'Wiki', 'YouTube', 'Email', 'Events', 'Support',
    'Advertising'
  ])),
  status text CHECK (status IS NULL OR status = ANY (ARRAY[
    'Backlog', 'Issue Open', 'PR Open', 'Pending Review', 'Listed',
    'Declined', 'Deferred', 'Dead', 'Active', 'Inactive', 'Pending', 'Posted'
  ])),
  priority text CHECK (priority IS NULL OR priority = ANY (ARRAY[
    'P0', 'P1', 'P2', 'High', 'Medium', 'Low'
  ])),
  link text,
  owned boolean NOT NULL DEFAULT false,
  last_version_told text,
  last_checked date,
  next_action text,
  notes text,
  legacy_airtable_id text UNIQUE,
  source_created_at timestamptz,
  source_record jsonb
);

CREATE TABLE IF NOT EXISTS public.log_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event text NOT NULL,
  occurred_at timestamptz NOT NULL,
  workflow text NOT NULL DEFAULT '',
  action text CHECK (action IS NULL OR action = ANY (ARRAY[
    'Submitted PR', 'Opened Issue', 'Commented', 'Rechecked', 'Status Change',
    'Claimed', 'Released Claim', 'Listed', 'Declined', 'Login', 'Upload',
    'Password Reset', 'Export', 'Logout', 'Generate Key', 'Update Profile',
    'Run Job', 'Change Permission', 'Delete', 'Error', 'Invite', 'Approve',
    'Resolved PR conflict', 'Posted discussion', 'Opened PR',
    'Reconciled live submission state', 'Verified and reopened free launch handoff',
    'Detected duplicate pending submissions'
  ])),
  result text,
  link text,
  operation_id uuid UNIQUE,
  legacy_airtable_id text UNIQUE,
  source_created_at timestamptz,
  source_record jsonb
);

CREATE TABLE IF NOT EXISTS public.log_targets (
  log_id bigint NOT NULL REFERENCES public.log_events(id) ON DELETE RESTRICT,
  target_key text NOT NULL REFERENCES public.targets(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  PRIMARY KEY (log_id, target_key)
);

CREATE TABLE IF NOT EXISTS public.bots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text,
  type text CHECK (type IS NULL OR type = ANY (ARRAY[
    'Automation', 'Manual', 'External API'
  ])),
  active boolean NOT NULL DEFAULT false,
  contact_info text,
  notes text,
  legacy_airtable_id text UNIQUE,
  source_created_at timestamptz,
  source_record jsonb
);

CREATE TABLE IF NOT EXISTS public.target_bots (
  target_key text NOT NULL REFERENCES public.targets(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  bot_id bigint NOT NULL REFERENCES public.bots(id) ON DELETE RESTRICT,
  PRIMARY KEY (target_key, bot_id)
);

CREATE TABLE IF NOT EXISTS public.merge_queue (
  key text PRIMARY KEY,
  proposed_at timestamptz,
  proposed_by_workflow text,
  target_data text,
  status text NOT NULL DEFAULT 'Pending' CHECK (status = ANY (ARRAY[
    'Pending', 'Merged', 'Rejected'
  ])),
  notes text,
  resolved_at timestamptz,
  resolved_by_workflow text,
  legacy_airtable_id text UNIQUE,
  source_created_at timestamptz,
  source_record jsonb
);

CREATE TABLE IF NOT EXISTS public.merge_queue_proposers (
  queue_key text NOT NULL REFERENCES public.merge_queue(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  bot_id bigint NOT NULL REFERENCES public.bots(id) ON DELETE RESTRICT,
  PRIMARY KEY (queue_key, bot_id)
);

CREATE TABLE IF NOT EXISTS public.merge_queue_duplicates (
  queue_key text NOT NULL REFERENCES public.merge_queue(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  duplicate_of_key text NOT NULL REFERENCES public.merge_queue(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  PRIMARY KEY (queue_key, duplicate_of_key),
  CHECK (queue_key <> duplicate_of_key)
);

CREATE TABLE IF NOT EXISTS public.merge_queue_targets (
  queue_key text NOT NULL REFERENCES public.merge_queue(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  target_key text NOT NULL REFERENCES public.targets(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  PRIMARY KEY (queue_key, target_key)
);

CREATE TABLE IF NOT EXISTS public.claims (
  key text PRIMARY KEY,
  target_key text NOT NULL REFERENCES public.targets(key) ON UPDATE CASCADE ON DELETE RESTRICT,
  workflow text NOT NULL,
  claimed_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  released_at timestamptz,
  legacy_airtable_id text UNIQUE,
  source_created_at timestamptz,
  source_record jsonb,
  CHECK (expires_at >= claimed_at),
  CHECK (released_at IS NULL OR released_at >= claimed_at)
);

CREATE INDEX IF NOT EXISTS targets_status_idx ON public.targets(status);
CREATE INDEX IF NOT EXISTS targets_priority_idx ON public.targets(priority);
CREATE INDEX IF NOT EXISTS targets_channel_idx ON public.targets(channel);
CREATE INDEX IF NOT EXISTS claims_active_idx
  ON public.claims(target_key, expires_at)
  WHERE released_at IS NULL;
CREATE INDEX IF NOT EXISTS log_events_occurred_idx ON public.log_events(occurred_at);
CREATE INDEX IF NOT EXISTS merge_queue_status_idx ON public.merge_queue(status);

CREATE TABLE IF NOT EXISTS outreach_private.migration_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source text NOT NULL,
  source_base_id text NOT NULL,
  exported_at timestamptz NOT NULL,
  sha256 text NOT NULL UNIQUE CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  record_counts jsonb NOT NULL,
  payload jsonb NOT NULL,
  verified_at timestamptz
);

CREATE OR REPLACE FUNCTION outreach_private.airtable_scalar(
  p_fields jsonb,
  p_name text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE jsonb_typeof(p_fields -> p_name)
    WHEN 'array' THEN p_fields -> p_name ->> 0
    ELSE p_fields ->> p_name
  END
$$;

CREATE OR REPLACE FUNCTION outreach_private.reject_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF current_setting('outreach.migration', true) = 'on' THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'outreach logs are append-only' USING ERRCODE = '55000';
END
$$;

CREATE OR REPLACE FUNCTION outreach_private.guard_claim_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF current_setting('outreach.migration', true) = 'on' THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'outreach claims are append-only' USING ERRCODE = '55000';
  END IF;
  IF (to_jsonb(NEW) - 'released_at') IS DISTINCT FROM
     (to_jsonb(OLD) - 'released_at')
     OR OLD.released_at IS NOT NULL
     OR NEW.released_at IS NULL THEN
    RAISE EXCEPTION 'claims may only be released once' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS log_events_append_only ON public.log_events;
CREATE TRIGGER log_events_append_only
BEFORE UPDATE OR DELETE ON public.log_events
FOR EACH ROW EXECUTE FUNCTION outreach_private.reject_log_mutation();

DROP TRIGGER IF EXISTS claims_append_only ON public.claims;
CREATE TRIGGER claims_append_only
BEFORE UPDATE OR DELETE ON public.claims
FOR EACH ROW EXECUTE FUNCTION outreach_private.guard_claim_mutation();

DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'targets', 'log_events', 'log_targets', 'bots', 'target_bots',
    'merge_queue', 'merge_queue_proposers', 'merge_queue_duplicates',
    'merge_queue_targets', 'claims'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC', table_name);
    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM outreach_tracker', table_name);
  END LOOP;
END
$$;

REVOKE ALL ON ALL TABLES IN SCHEMA outreach_private FROM PUBLIC, outreach_tracker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, outreach_tracker;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA outreach_private FROM PUBLIC, outreach_tracker;
GRANT USAGE ON SCHEMA public TO outreach_tracker;

CREATE OR REPLACE FUNCTION outreach_private.assert_tracker()
RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  IF COALESCE(auth.user_id(), '') <> 'codex-profiles-outreach-agent' THEN
    RAISE EXCEPTION 'outreach tracker identity required' USING ERRCODE = '42501';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION outreach_private.append_log(
  p_target_key text,
  p_workflow text,
  p_action text,
  p_result text,
  p_link text,
  p_operation_id uuid,
  p_now timestamptz DEFAULT clock_timestamp()
)
RETURNS bigint
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, public, outreach_private
AS $$
DECLARE
  log_id bigint;
BEGIN
  INSERT INTO public.log_events (
    event, occurred_at, workflow, action, result, link, operation_id
  ) VALUES (
    p_action || ' — ' || p_target_key,
    p_now,
    COALESCE(p_workflow, ''),
    p_action,
    NULLIF(p_result, ''),
    NULLIF(p_link, ''),
    p_operation_id
  )
  ON CONFLICT (operation_id) DO NOTHING
  RETURNING id INTO log_id;

  IF log_id IS NULL THEN
    SELECT id INTO log_id
    FROM public.log_events
    WHERE operation_id = p_operation_id;
  END IF;

  IF EXISTS (SELECT 1 FROM public.targets WHERE key = p_target_key) THEN
    INSERT INTO public.log_targets (log_id, target_key)
    VALUES (log_id, p_target_key)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN log_id;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_list_targets(
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_channel text DEFAULT NULL,
  p_owned boolean DEFAULT NULL
)
RETURNS SETOF public.targets
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  RETURN QUERY
    SELECT * FROM public.targets t
    WHERE (p_status IS NULL OR t.status = p_status)
      AND (p_priority IS NULL OR t.priority = p_priority)
      AND (p_channel IS NULL OR t.channel = p_channel)
      AND (p_owned IS NULL OR t.owned = p_owned)
    ORDER BY t.key;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_get_target(p_key text)
RETURNS SETOF public.targets
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  RETURN QUERY SELECT * FROM public.targets WHERE key = p_key;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_upsert_target(p_key text, p_patch jsonb)
RETURNS SETOF public.targets
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  INSERT INTO public.targets (
    key, name, channel, status, priority, link, owned, last_version_told,
    last_checked, next_action, notes
  ) VALUES (
    p_key,
    p_patch->>'Name',
    p_patch->>'Channel',
    p_patch->>'Status',
    p_patch->>'Priority',
    p_patch->>'Link',
    COALESCE((p_patch->>'Owned?')::boolean, false),
    p_patch->>'Last Version Told',
    (p_patch->>'Last Checked')::date,
    p_patch->>'Next Action',
    p_patch->>'Notes'
  )
  ON CONFLICT (key) DO UPDATE SET
    name = CASE WHEN p_patch ? 'Name' THEN EXCLUDED.name ELSE targets.name END,
    channel = CASE WHEN p_patch ? 'Channel' THEN EXCLUDED.channel ELSE targets.channel END,
    status = CASE WHEN p_patch ? 'Status' THEN EXCLUDED.status ELSE targets.status END,
    priority = CASE WHEN p_patch ? 'Priority' THEN EXCLUDED.priority ELSE targets.priority END,
    link = CASE WHEN p_patch ? 'Link' THEN EXCLUDED.link ELSE targets.link END,
    owned = CASE WHEN p_patch ? 'Owned?' THEN EXCLUDED.owned ELSE targets.owned END,
    last_version_told = CASE WHEN p_patch ? 'Last Version Told' THEN EXCLUDED.last_version_told ELSE targets.last_version_told END,
    last_checked = CASE WHEN p_patch ? 'Last Checked' THEN EXCLUDED.last_checked ELSE targets.last_checked END,
    next_action = CASE WHEN p_patch ? 'Next Action' THEN EXCLUDED.next_action ELSE targets.next_action END,
    notes = CASE WHEN p_patch ? 'Notes' THEN EXCLUDED.notes ELSE targets.notes END;

  RETURN QUERY SELECT * FROM public.targets WHERE key = p_key;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_append_log(
  p_target_key text,
  p_workflow text,
  p_action text,
  p_result text DEFAULT NULL,
  p_link text DEFAULT NULL,
  p_operation_id uuid DEFAULT gen_random_uuid()
)
RETURNS TABLE(log_id bigint)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  RETURN QUERY SELECT outreach_private.append_log(
    p_target_key, p_workflow, p_action, p_result, p_link, p_operation_id
  );
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_set_status(
  p_key text,
  p_status text,
  p_operation_id uuid DEFAULT gen_random_uuid()
)
RETURNS SETOF public.targets
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  INSERT INTO public.targets (key, status) VALUES (p_key, p_status)
  ON CONFLICT (key) DO UPDATE SET status = EXCLUDED.status;
  PERFORM outreach_private.append_log(
    p_key, '', 'Status Change', '-> ' || p_status, NULL, p_operation_id
  );
  RETURN QUERY SELECT * FROM public.targets WHERE key = p_key;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_claim(
  p_key text,
  p_workflow text,
  p_ttl_ms bigint,
  p_operation_id uuid DEFAULT gen_random_uuid()
)
RETURNS TABLE(outcome text, claim_key text, holder text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
DECLARE
  active_claim public.claims%ROWTYPE;
  new_key text;
  now_at timestamptz := clock_timestamp();
BEGIN
  PERFORM outreach_private.assert_tracker();
  IF p_ttl_ms < 0 THEN
    RAISE EXCEPTION 'claim TTL must be non-negative' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.targets WHERE key = p_key) THEN
    RAISE EXCEPTION 'No target with Key=%', p_key USING ERRCODE = 'P0002';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_key, 0));

  SELECT * INTO active_claim
  FROM public.claims
  WHERE target_key = p_key
    AND released_at IS NULL
    AND expires_at > now_at
    AND workflow = p_workflow
  ORDER BY claimed_at, key
  LIMIT 1;
  IF FOUND THEN
    RETURN QUERY SELECT 'owned', active_claim.key, active_claim.workflow;
    RETURN;
  END IF;

  SELECT * INTO active_claim
  FROM public.claims
  WHERE target_key = p_key
    AND released_at IS NULL
    AND expires_at > now_at
  ORDER BY claimed_at, key
  LIMIT 1;
  IF FOUND THEN
    RETURN QUERY SELECT 'lost', active_claim.key, active_claim.workflow;
    RETURN;
  END IF;

  new_key := p_key || ':' || p_workflow || ':' || gen_random_uuid()::text;
  INSERT INTO public.claims (key, target_key, workflow, claimed_at, expires_at)
  VALUES (
    new_key, p_key, p_workflow, now_at,
    now_at + (p_ttl_ms::text || ' milliseconds')::interval
  );
  PERFORM outreach_private.append_log(
    p_key, p_workflow, 'Claimed', NULL, NULL, p_operation_id, now_at
  );
  RETURN QUERY SELECT 'claimed', new_key, p_workflow;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_release(
  p_key text,
  p_workflow text,
  p_operation_id uuid DEFAULT gen_random_uuid()
)
RETURNS TABLE(outcome text, released_count bigint)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
DECLARE
  changed bigint;
  now_at timestamptz := clock_timestamp();
BEGIN
  PERFORM outreach_private.assert_tracker();
  IF NOT EXISTS (SELECT 1 FROM public.targets WHERE key = p_key) THEN
    RAISE EXCEPTION 'No target with Key=%', p_key USING ERRCODE = 'P0002';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_key, 0));
  IF NOT EXISTS (
    SELECT 1 FROM public.claims WHERE target_key = p_key AND workflow = p_workflow
  ) THEN
    RETURN QUERY SELECT 'never', 0::bigint;
    RETURN;
  END IF;

  UPDATE public.claims
  SET released_at = now_at
  WHERE target_key = p_key
    AND workflow = p_workflow
    AND released_at IS NULL
    AND expires_at > now_at;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed = 0 THEN
    RETURN QUERY SELECT 'inactive', 0::bigint;
    RETURN;
  END IF;
  PERFORM outreach_private.append_log(
    p_key, p_workflow, 'Released Claim', NULL, NULL, p_operation_id, now_at
  );
  RETURN QUERY SELECT 'released', changed;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_list_queue(p_status text DEFAULT NULL)
RETURNS TABLE(
  key text,
  proposed_at timestamptz,
  proposed_by_workflow text,
  target_data text,
  status text,
  notes text,
  resolved_at timestamptz,
  resolved_by_workflow text,
  proposed_by text[],
  linked_targets text[],
  duplicate_of text[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  RETURN QUERY
    SELECT q.key, q.proposed_at, q.proposed_by_workflow, q.target_data,
      q.status, q.notes, q.resolved_at, q.resolved_by_workflow,
      ARRAY(
        SELECT b.name FROM public.merge_queue_proposers p
        JOIN public.bots b ON b.id = p.bot_id
        WHERE p.queue_key = q.key ORDER BY b.name
      ),
      ARRAY(
        SELECT x.target_key FROM public.merge_queue_targets x
        WHERE x.queue_key = q.key ORDER BY x.target_key
      ),
      ARRAY(
        SELECT x.duplicate_of_key FROM public.merge_queue_duplicates x
        WHERE x.queue_key = q.key ORDER BY x.duplicate_of_key
      )
    FROM public.merge_queue q
    WHERE p_status IS NULL OR q.status = p_status
    ORDER BY q.proposed_at NULLS LAST, q.key;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_enqueue(
  p_key text,
  p_workflow text,
  p_target_data text,
  p_linked_target text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS SETOF public.merge_queue
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  IF p_linked_target IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.targets WHERE key = p_linked_target) THEN
    RAISE EXCEPTION 'No target with Key=%', p_linked_target USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.merge_queue (
    key, proposed_at, proposed_by_workflow, target_data, status, notes
  ) VALUES (
    p_key, clock_timestamp(), p_workflow, p_target_data, 'Pending', p_notes
  )
  ON CONFLICT (key) DO UPDATE SET
    proposed_by_workflow = EXCLUDED.proposed_by_workflow,
    target_data = EXCLUDED.target_data,
    notes = COALESCE(EXCLUDED.notes, merge_queue.notes);

  IF p_linked_target IS NOT NULL THEN
    INSERT INTO public.merge_queue_targets (queue_key, target_key)
    VALUES (p_key, p_linked_target)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN QUERY SELECT * FROM public.merge_queue WHERE key = p_key;
END
$$;

CREATE OR REPLACE FUNCTION public.tracker_resolve_queue(
  p_key text,
  p_workflow text,
  p_status text,
  p_linked_target text DEFAULT NULL,
  p_duplicate_of text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS SETOF public.merge_queue
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, public, outreach_private
AS $$
BEGIN
  PERFORM outreach_private.assert_tracker();
  IF p_status NOT IN ('Merged', 'Rejected') THEN
    RAISE EXCEPTION 'queue resolution must be Merged or Rejected' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.merge_queue WHERE key = p_key) THEN
    RAISE EXCEPTION 'No queue item with Key=%', p_key USING ERRCODE = 'P0002';
  END IF;
  IF p_linked_target IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.targets WHERE key = p_linked_target) THEN
    RAISE EXCEPTION 'No target with Key=%', p_linked_target USING ERRCODE = 'P0002';
  END IF;
  IF p_duplicate_of IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.merge_queue WHERE key = p_duplicate_of) THEN
    RAISE EXCEPTION 'No queue item with Key=%', p_duplicate_of USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.merge_queue SET
    status = p_status,
    resolved_at = clock_timestamp(),
    resolved_by_workflow = p_workflow,
    notes = COALESCE(p_notes, notes)
  WHERE key = p_key;

  IF p_linked_target IS NOT NULL THEN
    INSERT INTO public.merge_queue_targets (queue_key, target_key)
    VALUES (p_key, p_linked_target)
    ON CONFLICT DO NOTHING;
  END IF;
  IF p_duplicate_of IS NOT NULL THEN
    INSERT INTO public.merge_queue_duplicates (queue_key, duplicate_of_key)
    VALUES (p_key, p_duplicate_of)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN QUERY SELECT * FROM public.merge_queue WHERE key = p_key;
END
$$;

CREATE OR REPLACE FUNCTION outreach_private.verify_airtable_snapshot(p_snapshot jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, public, outreach_private
AS $$
DECLARE
  expected_counts jsonb;
  actual_counts jsonb;
  raw_mismatches bigint;
  relationship_mismatches bigint;
  expected_unlinked_logs bigint;
  actual_unlinked_logs bigint;
  active_claims bigint;
BEGIN
  expected_counts := jsonb_build_object(
    'targets', jsonb_array_length(p_snapshot #> '{tables,targets,records}'),
    'logEvents', jsonb_array_length(p_snapshot #> '{tables,logEvents,records}'),
    'claims', jsonb_array_length(p_snapshot #> '{tables,claims,records}'),
    'bots', jsonb_array_length(p_snapshot #> '{tables,bots,records}'),
    'mergeQueue', jsonb_array_length(p_snapshot #> '{tables,mergeQueue,records}')
  );
  actual_counts := jsonb_build_object(
    'targets', (SELECT count(*) FROM public.targets WHERE legacy_airtable_id IS NOT NULL),
    'logEvents', (SELECT count(*) FROM public.log_events WHERE legacy_airtable_id IS NOT NULL),
    'claims', (SELECT count(*) FROM public.claims WHERE legacy_airtable_id IS NOT NULL),
    'bots', (SELECT count(*) FROM public.bots WHERE legacy_airtable_id IS NOT NULL),
    'mergeQueue', (SELECT count(*) FROM public.merge_queue WHERE legacy_airtable_id IS NOT NULL)
  );

  WITH expected AS (
    SELECT table_entry.key AS kind, record AS source_record
    FROM jsonb_each(p_snapshot -> 'tables') AS table_entry
    CROSS JOIN LATERAL jsonb_array_elements(table_entry.value -> 'records') AS record
  ), actual AS (
    SELECT 'targets' AS kind, legacy_airtable_id, source_record FROM public.targets
      WHERE legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'logEvents', legacy_airtable_id, source_record FROM public.log_events
      WHERE legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'claims', legacy_airtable_id, source_record FROM public.claims
      WHERE legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'bots', legacy_airtable_id, source_record FROM public.bots
      WHERE legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'mergeQueue', legacy_airtable_id, source_record FROM public.merge_queue
      WHERE legacy_airtable_id IS NOT NULL
  )
  SELECT count(*) INTO raw_mismatches
  FROM expected e
  FULL JOIN actual a
    ON a.kind = e.kind AND a.legacy_airtable_id = e.source_record ->> 'id'
  WHERE e.source_record IS DISTINCT FROM a.source_record;

  WITH expected AS (
    SELECT link_entry.key AS kind, pair
    FROM jsonb_each(p_snapshot -> 'links') AS link_entry
    CROSS JOIN LATERAL jsonb_array_elements(link_entry.value) AS pair
  ), actual AS (
    SELECT 'logTargets' AS kind,
      jsonb_build_object('logId', l.legacy_airtable_id, 'targetId', t.legacy_airtable_id) AS pair
    FROM public.log_targets x
    JOIN public.log_events l ON l.id = x.log_id
    JOIN public.targets t ON t.key = x.target_key
    WHERE l.legacy_airtable_id IS NOT NULL AND t.legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'targetBots',
      jsonb_build_object('targetId', t.legacy_airtable_id, 'botId', b.legacy_airtable_id)
    FROM public.target_bots x
    JOIN public.targets t ON t.key = x.target_key
    JOIN public.bots b ON b.id = x.bot_id
    WHERE t.legacy_airtable_id IS NOT NULL AND b.legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'queueProposers',
      jsonb_build_object('queueId', q.legacy_airtable_id, 'botId', b.legacy_airtable_id)
    FROM public.merge_queue_proposers x
    JOIN public.merge_queue q ON q.key = x.queue_key
    JOIN public.bots b ON b.id = x.bot_id
    WHERE q.legacy_airtable_id IS NOT NULL AND b.legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'queueDuplicates',
      jsonb_build_object('queueId', q.legacy_airtable_id, 'duplicateOfId', d.legacy_airtable_id)
    FROM public.merge_queue_duplicates x
    JOIN public.merge_queue q ON q.key = x.queue_key
    JOIN public.merge_queue d ON d.key = x.duplicate_of_key
    WHERE q.legacy_airtable_id IS NOT NULL AND d.legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'queueTargets',
      jsonb_build_object('queueId', q.legacy_airtable_id, 'targetId', t.legacy_airtable_id)
    FROM public.merge_queue_targets x
    JOIN public.merge_queue q ON q.key = x.queue_key
    JOIN public.targets t ON t.key = x.target_key
    WHERE q.legacy_airtable_id IS NOT NULL AND t.legacy_airtable_id IS NOT NULL
    UNION ALL
    SELECT 'claimTargets',
      jsonb_build_object('claimId', c.legacy_airtable_id, 'targetId', t.legacy_airtable_id)
    FROM public.claims c
    JOIN public.targets t ON t.key = c.target_key
    WHERE c.legacy_airtable_id IS NOT NULL AND t.legacy_airtable_id IS NOT NULL
  )
  SELECT count(*) INTO relationship_mismatches
  FROM expected e
  FULL JOIN actual a ON a.kind = e.kind AND a.pair = e.pair
  WHERE e.pair IS NULL OR a.pair IS NULL;

  expected_unlinked_logs := jsonb_array_length(p_snapshot #> '{tables,logEvents,records}')
    - (SELECT count(DISTINCT pair ->> 'logId')
       FROM jsonb_array_elements(p_snapshot #> '{links,logTargets}') AS pair);
  SELECT count(*) INTO actual_unlinked_logs
  FROM public.log_events l
  WHERE l.legacy_airtable_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.log_targets x WHERE x.log_id = l.id);
  SELECT count(*) INTO active_claims
  FROM public.claims
  WHERE released_at IS NULL AND expires_at > clock_timestamp();

  RETURN jsonb_build_object(
    'ok', expected_counts = actual_counts
      AND raw_mismatches = 0
      AND relationship_mismatches = 0
      AND expected_unlinked_logs = actual_unlinked_logs,
    'sha256', p_snapshot ->> 'sha256',
    'expectedCounts', expected_counts,
    'actualCounts', actual_counts,
    'rawRecordMismatches', raw_mismatches,
    'relationshipMismatches', relationship_mismatches,
    'expectedUnlinkedLogs', expected_unlinked_logs,
    'actualUnlinkedLogs', actual_unlinked_logs,
    'activeClaims', active_claims
  );
END
$$;

CREATE OR REPLACE FUNCTION outreach_private.import_airtable_snapshot(
  p_snapshot jsonb,
  p_sync boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, public, outreach_private
AS $$
DECLARE
  record jsonb;
  fields jsonb;
  link_record jsonb;
  target_key_value text;
  report jsonb;
  source_row_count bigint;
BEGIN
  IF p_snapshot ->> 'format' <> 'codex-profiles-airtable-snapshot-v1'
    OR p_snapshot #>> '{source,baseId}' IS NULL
    OR COALESCE(p_snapshot ->> 'sha256', '') !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid outreach snapshot envelope' USING ERRCODE = '22023';
  END IF;
  IF NOT p_sync AND EXISTS (
    SELECT FROM public.targets UNION ALL SELECT FROM public.log_events
    UNION ALL SELECT FROM public.claims UNION ALL SELECT FROM public.bots
    UNION ALL SELECT FROM public.merge_queue
  ) THEN
    RAISE EXCEPTION 'destination is not empty; use explicit sync' USING ERRCODE = '55000';
  END IF;

  IF p_sync AND EXISTS (
    WITH existing AS (
      SELECT 'targets' AS kind, legacy_airtable_id AS id FROM public.targets
        WHERE legacy_airtable_id IS NOT NULL
      UNION ALL SELECT 'logEvents', legacy_airtable_id FROM public.log_events
        WHERE legacy_airtable_id IS NOT NULL
      UNION ALL SELECT 'claims', legacy_airtable_id FROM public.claims
        WHERE legacy_airtable_id IS NOT NULL
      UNION ALL SELECT 'bots', legacy_airtable_id FROM public.bots
        WHERE legacy_airtable_id IS NOT NULL
      UNION ALL SELECT 'mergeQueue', legacy_airtable_id FROM public.merge_queue
        WHERE legacy_airtable_id IS NOT NULL
    )
    SELECT FROM existing e
    WHERE NOT EXISTS (
      SELECT FROM jsonb_array_elements(
        p_snapshot #> ARRAY['tables', e.kind, 'records']
      ) AS source_record
      WHERE source_record ->> 'id' = e.id
    )
  ) THEN
    RAISE EXCEPTION 'source deletion detected; sync refused' USING ERRCODE = '55000';
  END IF;

  PERFORM set_config('outreach.migration', 'on', true);

  FOR record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{tables,targets,records}')
  LOOP
    fields := record -> 'fields';
    IF NULLIF(fields ->> 'Key', '') IS NULL THEN
      RAISE EXCEPTION 'Target % has no Key', record ->> 'id' USING ERRCODE = '23502';
    END IF;
    INSERT INTO public.targets (
      key, name, channel, status, priority, link, owned, last_version_told,
      last_checked, next_action, notes, legacy_airtable_id, source_created_at,
      source_record
    ) VALUES (
      fields ->> 'Key', fields ->> 'Name', fields ->> 'Channel',
      fields ->> 'Status', fields ->> 'Priority', fields ->> 'Link',
      COALESCE((fields ->> 'Owned?')::boolean, false),
      fields ->> 'Last Version Told', NULLIF(fields ->> 'Last Checked', '')::date,
      fields ->> 'Next Action', fields ->> 'Notes', record ->> 'id',
      (record ->> 'createdTime')::timestamptz, record
    )
    ON CONFLICT (legacy_airtable_id) DO UPDATE SET
      key = EXCLUDED.key, name = EXCLUDED.name, channel = EXCLUDED.channel,
      status = EXCLUDED.status, priority = EXCLUDED.priority, link = EXCLUDED.link,
      owned = EXCLUDED.owned, last_version_told = EXCLUDED.last_version_told,
      last_checked = EXCLUDED.last_checked, next_action = EXCLUDED.next_action,
      notes = EXCLUDED.notes, source_created_at = EXCLUDED.source_created_at,
      source_record = EXCLUDED.source_record;
  END LOOP;

  FOR record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{tables,logEvents,records}')
  LOOP
    fields := record -> 'fields';
    INSERT INTO public.log_events (
      event, occurred_at, workflow, action, result, link, legacy_airtable_id,
      source_created_at, source_record
    ) VALUES (
      fields ->> 'Event', NULLIF(fields ->> 'Timestamp', '')::timestamptz,
      COALESCE(fields ->> 'Workflow', ''), fields ->> 'Action',
      fields ->> 'Result', fields ->> 'Link', record ->> 'id',
      (record ->> 'createdTime')::timestamptz, record
    )
    ON CONFLICT (legacy_airtable_id) DO UPDATE SET
      event = EXCLUDED.event, occurred_at = EXCLUDED.occurred_at,
      workflow = EXCLUDED.workflow, action = EXCLUDED.action,
      result = EXCLUDED.result, link = EXCLUDED.link,
      source_created_at = EXCLUDED.source_created_at,
      source_record = EXCLUDED.source_record;
  END LOOP;

  FOR record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{tables,bots,records}')
  LOOP
    fields := record -> 'fields';
    INSERT INTO public.bots (
      name, type, active, contact_info, notes, legacy_airtable_id,
      source_created_at, source_record
    ) VALUES (
      fields ->> 'Name', fields ->> 'Type',
      COALESCE((fields ->> 'Active')::boolean, false),
      fields ->> 'Contact Info', fields ->> 'Notes', record ->> 'id',
      (record ->> 'createdTime')::timestamptz, record
    )
    ON CONFLICT (legacy_airtable_id) DO UPDATE SET
      name = EXCLUDED.name, type = EXCLUDED.type, active = EXCLUDED.active,
      contact_info = EXCLUDED.contact_info, notes = EXCLUDED.notes,
      source_created_at = EXCLUDED.source_created_at,
      source_record = EXCLUDED.source_record;
  END LOOP;

  FOR record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{tables,mergeQueue,records}')
  LOOP
    fields := record -> 'fields';
    INSERT INTO public.merge_queue (
      key, proposed_at, proposed_by_workflow, target_data, status, notes,
      legacy_airtable_id, source_created_at, source_record
    ) VALUES (
      COALESCE(NULLIF(fields ->> 'Key', ''), record ->> 'id'),
      NULLIF(fields ->> 'Timestamp', '')::timestamptz,
      fields ->> 'Proposed By Workflow', fields ->> 'Target Data',
      COALESCE(NULLIF(fields ->> 'Status', ''), 'Pending'), fields ->> 'Notes',
      record ->> 'id', (record ->> 'createdTime')::timestamptz, record
    )
    ON CONFLICT (legacy_airtable_id) DO UPDATE SET
      key = EXCLUDED.key, proposed_at = EXCLUDED.proposed_at,
      proposed_by_workflow = EXCLUDED.proposed_by_workflow,
      target_data = EXCLUDED.target_data, status = EXCLUDED.status,
      notes = EXCLUDED.notes, source_created_at = EXCLUDED.source_created_at,
      source_record = EXCLUDED.source_record;
  END LOOP;

  FOR record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{tables,claims,records}')
  LOOP
    fields := record -> 'fields';
    SELECT t.key INTO target_key_value
    FROM public.targets t
    WHERE t.legacy_airtable_id = fields -> 'Target' ->> 0;
    target_key_value := COALESCE(
      target_key_value,
      outreach_private.airtable_scalar(fields, 'Target Key')
    );
    IF target_key_value IS NULL THEN
      RAISE EXCEPTION 'Claim % has no target', record ->> 'id' USING ERRCODE = '23503';
    END IF;
    INSERT INTO public.claims (
      key, target_key, workflow, claimed_at, expires_at, released_at,
      legacy_airtable_id, source_created_at, source_record
    ) VALUES (
      COALESCE(NULLIF(fields ->> 'Key', ''), record ->> 'id'),
      target_key_value, COALESCE(fields ->> 'Workflow', ''),
      (fields ->> 'Claimed At')::timestamptz,
      (fields ->> 'Expires At')::timestamptz,
      NULLIF(fields ->> 'Released At', '')::timestamptz,
      record ->> 'id', (record ->> 'createdTime')::timestamptz, record
    )
    ON CONFLICT (legacy_airtable_id) DO UPDATE SET
      key = EXCLUDED.key, target_key = EXCLUDED.target_key,
      workflow = EXCLUDED.workflow, claimed_at = EXCLUDED.claimed_at,
      expires_at = EXCLUDED.expires_at, released_at = EXCLUDED.released_at,
      source_created_at = EXCLUDED.source_created_at,
      source_record = EXCLUDED.source_record;
  END LOOP;

  DELETE FROM public.log_targets x USING public.log_events l
    WHERE x.log_id = l.id AND l.legacy_airtable_id IS NOT NULL;
  DELETE FROM public.target_bots x USING public.targets t
    WHERE x.target_key = t.key AND t.legacy_airtable_id IS NOT NULL;
  DELETE FROM public.merge_queue_proposers x USING public.merge_queue q
    WHERE x.queue_key = q.key AND q.legacy_airtable_id IS NOT NULL;
  DELETE FROM public.merge_queue_duplicates x USING public.merge_queue q
    WHERE x.queue_key = q.key AND q.legacy_airtable_id IS NOT NULL;
  DELETE FROM public.merge_queue_targets x USING public.merge_queue q
    WHERE x.queue_key = q.key AND q.legacy_airtable_id IS NOT NULL;

  FOR link_record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{links,logTargets}')
  LOOP
    INSERT INTO public.log_targets (log_id, target_key)
    SELECT l.id, t.key FROM public.log_events l, public.targets t
    WHERE l.legacy_airtable_id = link_record ->> 'logId'
      AND t.legacy_airtable_id = link_record ->> 'targetId';
  END LOOP;
  FOR link_record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{links,targetBots}')
  LOOP
    INSERT INTO public.target_bots (target_key, bot_id)
    SELECT t.key, b.id FROM public.targets t, public.bots b
    WHERE t.legacy_airtable_id = link_record ->> 'targetId'
      AND b.legacy_airtable_id = link_record ->> 'botId';
  END LOOP;
  FOR link_record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{links,queueProposers}')
  LOOP
    INSERT INTO public.merge_queue_proposers (queue_key, bot_id)
    SELECT q.key, b.id FROM public.merge_queue q, public.bots b
    WHERE q.legacy_airtable_id = link_record ->> 'queueId'
      AND b.legacy_airtable_id = link_record ->> 'botId';
  END LOOP;
  FOR link_record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{links,queueDuplicates}')
  LOOP
    INSERT INTO public.merge_queue_duplicates (queue_key, duplicate_of_key)
    SELECT q.key, d.key FROM public.merge_queue q, public.merge_queue d
    WHERE q.legacy_airtable_id = link_record ->> 'queueId'
      AND d.legacy_airtable_id = link_record ->> 'duplicateOfId';
  END LOOP;
  FOR link_record IN SELECT value FROM jsonb_array_elements(p_snapshot #> '{links,queueTargets}')
  LOOP
    INSERT INTO public.merge_queue_targets (queue_key, target_key)
    SELECT q.key, t.key FROM public.merge_queue q, public.targets t
    WHERE q.legacy_airtable_id = link_record ->> 'queueId'
      AND t.legacy_airtable_id = link_record ->> 'targetId';
  END LOOP;

  source_row_count := jsonb_array_length(p_snapshot #> '{tables,targets,records}')
    + jsonb_array_length(p_snapshot #> '{tables,logEvents,records}')
    + jsonb_array_length(p_snapshot #> '{tables,claims,records}')
    + jsonb_array_length(p_snapshot #> '{tables,bots,records}')
    + jsonb_array_length(p_snapshot #> '{tables,mergeQueue,records}');
  IF source_row_count <> COALESCE((p_snapshot #>> '{counts,totalRecords}')::bigint, -1) THEN
    RAISE EXCEPTION 'snapshot record count does not match its envelope' USING ERRCODE = '22023';
  END IF;

  INSERT INTO outreach_private.migration_snapshots (
    source, source_base_id, exported_at, sha256, record_counts, payload
  ) VALUES (
    'airtable', p_snapshot #>> '{source,baseId}',
    (p_snapshot ->> 'exportedAt')::timestamptz, p_snapshot ->> 'sha256',
    p_snapshot -> 'counts', p_snapshot
  )
  ON CONFLICT (sha256) DO UPDATE SET payload = EXCLUDED.payload;

  report := outreach_private.verify_airtable_snapshot(p_snapshot);
  IF NOT COALESCE((report ->> 'ok')::boolean, false) THEN
    RAISE EXCEPTION 'snapshot verification failed: %', report USING ERRCODE = '55000';
  END IF;
  UPDATE outreach_private.migration_snapshots
  SET verified_at = clock_timestamp()
  WHERE sha256 = p_snapshot ->> 'sha256';
  RETURN report;
END
$$;

REVOKE ALL ON FUNCTION outreach_private.verify_airtable_snapshot(jsonb) FROM PUBLIC, outreach_tracker;
REVOKE ALL ON FUNCTION outreach_private.import_airtable_snapshot(jsonb, boolean) FROM PUBLIC, outreach_tracker;

REVOKE ALL ON FUNCTION public.tracker_list_targets(text, text, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_get_target(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_upsert_target(text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_append_log(text, text, text, text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_set_status(text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_claim(text, text, bigint, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_release(text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_list_queue(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_enqueue(text, text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tracker_resolve_queue(text, text, text, text, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.tracker_list_targets(text, text, text, boolean) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_get_target(text) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_upsert_target(text, jsonb) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_append_log(text, text, text, text, text, uuid) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_set_status(text, text, uuid) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_claim(text, text, bigint, uuid) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_release(text, text, uuid) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_list_queue(text) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_enqueue(text, text, text, text, text) TO outreach_tracker;
GRANT EXECUTE ON FUNCTION public.tracker_resolve_queue(text, text, text, text, text, text) TO outreach_tracker;

COMMIT;
