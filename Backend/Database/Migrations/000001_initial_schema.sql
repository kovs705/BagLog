BEGIN;

-- pg_trgm is bundled with PostgreSQL and supports typo-tolerant catalogue
-- search without introducing a separate search service on the Raspberry Pi.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE accounts (
    id uuid PRIMARY KEY,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deletion_requested_at timestamptz,
    CONSTRAINT accounts_status_check
        CHECK (status IN ('active', 'suspended', 'pending_deletion'))
);

CREATE TABLE auth_identities (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    provider text NOT NULL,
    provider_subject text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_authenticated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT auth_identities_provider_check
        CHECK (provider IN ('apple')),
    CONSTRAINT auth_identities_provider_subject_not_blank
        CHECK (btrim(provider_subject) <> ''),
    CONSTRAINT auth_identities_provider_subject_unique
        UNIQUE (provider, provider_subject)
);

CREATE INDEX auth_identities_account_id_idx
    ON auth_identities (account_id);

CREATE TABLE sessions (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    token_family_id uuid NOT NULL,
    refresh_token_hash bytea NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_used_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    CONSTRAINT sessions_refresh_token_hash_unique UNIQUE (refresh_token_hash),
    CONSTRAINT sessions_expiry_after_creation CHECK (expires_at > created_at)
);

CREATE INDEX sessions_active_account_idx
    ON sessions (account_id, expires_at)
    WHERE revoked_at IS NULL;

CREATE INDEX sessions_token_family_idx
    ON sessions (token_family_id);

CREATE TABLE profiles (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL UNIQUE REFERENCES accounts(id) ON DELETE CASCADE,
    handle varchar(30) NOT NULL,
    normalized_handle varchar(30)
        GENERATED ALWAYS AS (lower(btrim(handle))) STORED,
    display_name varchar(80) NOT NULL,
    bio varchar(500),
    avatar_media_id uuid,
    revision bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT profiles_handle_format
        CHECK (handle ~ '^[A-Za-z0-9_]{3,30}$'),
    CONSTRAINT profiles_display_name_not_blank
        CHECK (btrim(display_name) <> ''),
    CONSTRAINT profiles_revision_positive CHECK (revision > 0)
);

CREATE UNIQUE INDEX profiles_normalized_handle_unique
    ON profiles (normalized_handle);

CREATE TABLE media_objects (
    id uuid PRIMARY KEY,
    owner_profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    storage_key text NOT NULL UNIQUE,
    thumbnail_storage_key text UNIQUE,
    media_kind text NOT NULL,
    state text NOT NULL DEFAULT 'pending',
    content_type text,
    byte_size bigint,
    sha256 bytea,
    pixel_width integer,
    pixel_height integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    ready_at timestamptz,
    deleted_at timestamptz,
    CONSTRAINT media_objects_storage_key_not_blank
        CHECK (btrim(storage_key) <> ''),
    CONSTRAINT media_objects_media_kind_check
        CHECK (media_kind IN ('image', 'video')),
    CONSTRAINT media_objects_state_check
        CHECK (state IN ('pending', 'ready', 'quarantined', 'deleted')),
    CONSTRAINT media_objects_byte_size_check
        CHECK (byte_size IS NULL OR byte_size > 0),
    CONSTRAINT media_objects_sha256_length_check
        CHECK (sha256 IS NULL OR octet_length(sha256) = 32),
    CONSTRAINT media_objects_dimensions_check
        CHECK (
            (pixel_width IS NULL AND pixel_height IS NULL)
            OR (
                pixel_width IS NOT NULL
                AND pixel_height IS NOT NULL
                AND pixel_width > 0
                AND pixel_height > 0
            )
        ),
    CONSTRAINT media_objects_ready_fields_check
        CHECK (
            state <> 'ready'
            OR (
                content_type IS NOT NULL
                AND byte_size IS NOT NULL
                AND sha256 IS NOT NULL
                AND ready_at IS NOT NULL
            )
        )
);

CREATE INDEX media_objects_owner_created_idx
    ON media_objects (owner_profile_id, created_at DESC);

CREATE INDEX media_objects_pending_gc_idx
    ON media_objects (created_at)
    WHERE state = 'pending';

CREATE TABLE media_uploads (
    id uuid PRIMARY KEY,
    media_object_id uuid NOT NULL UNIQUE
        REFERENCES media_objects(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    expected_content_type text NOT NULL,
    expected_byte_size bigint NOT NULL,
    expected_sha256 bytea NOT NULL,
    state text NOT NULL DEFAULT 'prepared',
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    uploaded_at timestamptz,
    completed_at timestamptz,
    CONSTRAINT media_uploads_content_type_not_blank
        CHECK (btrim(expected_content_type) <> ''),
    CONSTRAINT media_uploads_byte_size_positive
        CHECK (expected_byte_size > 0),
    CONSTRAINT media_uploads_sha256_length_check
        CHECK (octet_length(expected_sha256) = 32),
    CONSTRAINT media_uploads_state_check
        CHECK (state IN ('prepared', 'uploaded', 'completed', 'expired')),
    CONSTRAINT media_uploads_expiry_check CHECK (expires_at > created_at),
    CONSTRAINT media_uploads_uploaded_state_check
        CHECK (state NOT IN ('uploaded', 'completed') OR uploaded_at IS NOT NULL),
    CONSTRAINT media_uploads_completed_state_check
        CHECK (state <> 'completed' OR completed_at IS NOT NULL)
);

CREATE INDEX media_uploads_account_created_idx
    ON media_uploads (account_id, created_at DESC);

CREATE INDEX media_uploads_expiry_idx
    ON media_uploads (expires_at)
    WHERE state IN ('prepared', 'uploaded');

ALTER TABLE profiles
    ADD CONSTRAINT profiles_avatar_media_id_fk
    FOREIGN KEY (avatar_media_id)
    REFERENCES media_objects(id)
    ON DELETE SET NULL;

CREATE TABLE loadouts (
    id uuid PRIMARY KEY,
    owner_profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title varchar(160) NOT NULL,
    summary varchar(4000) NOT NULL DEFAULT '',
    category varchar(80) NOT NULL,
    visibility text NOT NULL DEFAULT 'private',
    status text NOT NULL DEFAULT 'draft',
    moderation_state text NOT NULL DEFAULT 'not_reviewed',
    revision bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    archived_at timestamptz,
    deleted_at timestamptz,
    search_document tsvector
        GENERATED ALWAYS AS (
            to_tsvector(
                'simple'::regconfig,
                coalesce(title, '') || ' ' || coalesce(summary, '')
            )
        ) STORED,
    CONSTRAINT loadouts_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT loadouts_category_not_blank CHECK (btrim(category) <> ''),
    CONSTRAINT loadouts_visibility_check
        CHECK (visibility IN ('private', 'public')),
    CONSTRAINT loadouts_status_check
        CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT loadouts_moderation_state_check
        CHECK (
            moderation_state IN (
                'not_reviewed',
                'pending',
                'approved',
                'rejected',
                'hidden'
            )
        ),
    CONSTRAINT loadouts_revision_positive CHECK (revision > 0),
    CONSTRAINT loadouts_publication_fields_check
        CHECK (status <> 'published' OR published_at IS NOT NULL),
    CONSTRAINT loadouts_archival_fields_check
        CHECK (status <> 'archived' OR archived_at IS NOT NULL)
);

CREATE INDEX loadouts_owner_updated_idx
    ON loadouts (owner_profile_id, updated_at DESC, id)
    WHERE deleted_at IS NULL;

CREATE INDEX loadouts_owner_status_updated_idx
    ON loadouts (owner_profile_id, status, updated_at DESC, id)
    WHERE deleted_at IS NULL;

CREATE INDEX loadouts_public_catalogue_idx
    ON loadouts (published_at DESC, id)
    WHERE status = 'published'
      AND visibility = 'public'
      AND moderation_state = 'approved'
      AND deleted_at IS NULL;

CREATE INDEX loadouts_public_category_idx
    ON loadouts (category, published_at DESC, id)
    WHERE status = 'published'
      AND visibility = 'public'
      AND moderation_state = 'approved'
      AND deleted_at IS NULL;

CREATE INDEX loadouts_search_document_idx
    ON loadouts USING gin (search_document);

CREATE INDEX loadouts_title_trgm_idx
    ON loadouts USING gin (title gin_trgm_ops);

CREATE TABLE fork_origins (
    loadout_id uuid PRIMARY KEY REFERENCES loadouts(id) ON DELETE CASCADE,
    source_loadout_id uuid NOT NULL,
    root_loadout_id uuid NOT NULL,
    source_revision bigint NOT NULL,
    source_title varchar(160) NOT NULL,
    source_author_handle varchar(30) NOT NULL,
    forked_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fork_origins_source_revision_positive
        CHECK (source_revision > 0),
    CONSTRAINT fork_origins_source_title_not_blank
        CHECK (btrim(source_title) <> ''),
    CONSTRAINT fork_origins_source_author_not_blank
        CHECK (btrim(source_author_handle) <> ''),
    CONSTRAINT fork_origins_not_self
        CHECK (loadout_id <> source_loadout_id)
);

-- source_loadout_id and root_loadout_id intentionally are not foreign keys.
-- Attribution must survive deletion or moderation of the source loadout.
CREATE INDEX fork_origins_source_loadout_idx
    ON fork_origins (source_loadout_id);

CREATE INDEX fork_origins_root_loadout_idx
    ON fork_origins (root_loadout_id);

CREATE TABLE loadout_items (
    id uuid PRIMARY KEY,
    loadout_id uuid NOT NULL REFERENCES loadouts(id) ON DELETE CASCADE,
    title varchar(240) NOT NULL,
    category varchar(120),
    brand varchar(160),
    model varchar(160),
    notes varchar(4000),
    quantity integer NOT NULL DEFAULT 1,
    sort_index integer NOT NULL,
    is_essential boolean NOT NULL DEFAULT false,
    CONSTRAINT loadout_items_title_not_blank CHECK (btrim(title) <> ''),
    CONSTRAINT loadout_items_quantity_positive CHECK (quantity > 0),
    CONSTRAINT loadout_items_sort_index_nonnegative CHECK (sort_index >= 0),
    CONSTRAINT loadout_items_order_unique
        UNIQUE (loadout_id, sort_index) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX loadout_items_loadout_idx
    ON loadout_items (loadout_id);

CREATE TABLE item_links (
    id uuid PRIMARY KEY,
    item_id uuid NOT NULL REFERENCES loadout_items(id) ON DELETE CASCADE,
    url text NOT NULL,
    label varchar(160),
    sort_index integer NOT NULL,
    CONSTRAINT item_links_https_check CHECK (url ~* '^https://[^[:space:]]+$'),
    CONSTRAINT item_links_sort_index_nonnegative CHECK (sort_index >= 0),
    CONSTRAINT item_links_order_unique
        UNIQUE (item_id, sort_index) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX item_links_item_idx
    ON item_links (item_id);

CREATE TABLE loadout_assets (
    id uuid PRIMARY KEY,
    loadout_id uuid NOT NULL REFERENCES loadouts(id) ON DELETE CASCADE,
    media_object_id uuid NOT NULL REFERENCES media_objects(id) ON DELETE CASCADE,
    caption varchar(500),
    sort_index integer NOT NULL,
    CONSTRAINT loadout_assets_sort_index_nonnegative CHECK (sort_index >= 0),
    CONSTRAINT loadout_assets_order_unique
        UNIQUE (loadout_id, sort_index) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT loadout_assets_media_once_per_loadout
        UNIQUE (loadout_id, media_object_id)
);

CREATE INDEX loadout_assets_media_object_idx
    ON loadout_assets (media_object_id);

CREATE TABLE tags (
    id uuid PRIMARY KEY,
    name varchar(80) NOT NULL,
    normalized_name varchar(80) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tags_name_not_blank CHECK (btrim(name) <> ''),
    CONSTRAINT tags_normalized_name_not_blank CHECK (btrim(normalized_name) <> ''),
    CONSTRAINT tags_normalized_form_check
        CHECK (normalized_name = lower(btrim(normalized_name))),
    CONSTRAINT tags_normalized_name_unique UNIQUE (normalized_name)
);

CREATE INDEX tags_name_trgm_idx
    ON tags USING gin (name gin_trgm_ops);

CREATE TABLE loadout_tags (
    loadout_id uuid NOT NULL REFERENCES loadouts(id) ON DELETE CASCADE,
    tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (loadout_id, tag_id)
);

CREATE INDEX loadout_tags_tag_idx
    ON loadout_tags (tag_id, loadout_id);

CREATE TABLE saved_loadouts (
    id uuid PRIMARY KEY,
    profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    loadout_id uuid NOT NULL REFERENCES loadouts(id) ON DELETE CASCADE,
    saved_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT saved_loadouts_profile_loadout_unique
        UNIQUE (profile_id, loadout_id)
);

CREATE INDEX saved_loadouts_profile_saved_idx
    ON saved_loadouts (profile_id, saved_at DESC, id);

CREATE TABLE profile_blocks (
    blocker_profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_profile_id, blocked_profile_id),
    CONSTRAINT profile_blocks_not_self
        CHECK (blocker_profile_id <> blocked_profile_id)
);

CREATE INDEX profile_blocks_blocked_profile_idx
    ON profile_blocks (blocked_profile_id, blocker_profile_id);

CREATE TABLE content_reports (
    id uuid PRIMARY KEY,
    reporter_profile_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
    loadout_id uuid NOT NULL REFERENCES loadouts(id) ON DELETE CASCADE,
    reason text NOT NULL,
    details text,
    state text NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    resolved_by_account_id uuid REFERENCES accounts(id) ON DELETE SET NULL,
    resolution_notes text,
    CONSTRAINT content_reports_reason_check
        CHECK (
            reason IN (
                'spam',
                'harassment',
                'hate',
                'sexual',
                'violence',
                'illegal',
                'self_harm',
                'other'
            )
        ),
    CONSTRAINT content_reports_details_length
        CHECK (details IS NULL OR char_length(details) <= 2000),
    CONSTRAINT content_reports_state_check
        CHECK (state IN ('open', 'reviewing', 'resolved', 'dismissed')),
    CONSTRAINT content_reports_resolution_check
        CHECK (
            state NOT IN ('resolved', 'dismissed')
            OR resolved_at IS NOT NULL
        ),
    CONSTRAINT content_reports_reporter_loadout_unique
        UNIQUE (reporter_profile_id, loadout_id)
);

CREATE INDEX content_reports_open_created_idx
    ON content_reports (created_at, id)
    WHERE state IN ('open', 'reviewing');

CREATE INDEX content_reports_loadout_idx
    ON content_reports (loadout_id, created_at DESC);

-- The application inserts a row in the same transaction as each visible
-- aggregate change. Public catalogue activity is queried separately.
CREATE TABLE sync_changes (
    cursor bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    resource_type text NOT NULL,
    resource_id uuid NOT NULL,
    operation text NOT NULL,
    revision bigint,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT sync_changes_resource_type_check
        CHECK (resource_type IN ('profile', 'loadout')),
    CONSTRAINT sync_changes_operation_check
        CHECK (operation IN ('upsert', 'delete')),
    CONSTRAINT sync_changes_revision_check
        CHECK (revision IS NULL OR revision > 0),
    CONSTRAINT sync_changes_revision_operation_check
        CHECK (operation <> 'upsert' OR revision IS NOT NULL)
);

CREATE INDEX sync_changes_account_cursor_idx
    ON sync_changes (account_id, cursor);

-- Responses are retained only for the retry window and removed by a worker.
CREATE TABLE idempotency_keys (
    account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    idempotency_key uuid NOT NULL,
    request_hash bytea NOT NULL,
    state text NOT NULL DEFAULT 'processing',
    response_status integer,
    response_body jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    PRIMARY KEY (account_id, idempotency_key),
    CONSTRAINT idempotency_keys_state_check
        CHECK (state IN ('processing', 'completed')),
    CONSTRAINT idempotency_keys_response_status_check
        CHECK (response_status IS NULL OR response_status BETWEEN 100 AND 599),
    CONSTRAINT idempotency_keys_completion_check
        CHECK (
            state <> 'completed'
            OR (response_status IS NOT NULL AND response_body IS NOT NULL)
        ),
    CONSTRAINT idempotency_keys_expiry_check CHECK (expires_at > created_at)
);

CREATE INDEX idempotency_keys_expiry_idx
    ON idempotency_keys (expires_at);

-- Transactional outbox rows allow background work to move to separate worker
-- replicas without dual-writing the database and a broker.
CREATE TABLE outbox_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    event_type text NOT NULL,
    payload jsonb NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    available_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    attempts integer NOT NULL DEFAULT 0,
    CONSTRAINT outbox_events_aggregate_type_not_blank
        CHECK (btrim(aggregate_type) <> ''),
    CONSTRAINT outbox_events_event_type_not_blank
        CHECK (btrim(event_type) <> ''),
    CONSTRAINT outbox_events_attempts_nonnegative CHECK (attempts >= 0)
);

CREATE INDEX outbox_events_pending_idx
    ON outbox_events (available_at, id)
    WHERE published_at IS NULL;

COMMIT;
