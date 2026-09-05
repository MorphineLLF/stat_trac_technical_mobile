> # SUPERSEDED before execution — 2026-09-05
>
> **Read `C:\Delphi\GitHub_Stat_Trac_Go\docs\sync-design.md` instead.**
>
> This plan was written against an assumed greenfield database. That assumption
> was wrong. The Go repository already holds 84 PascalCase tables, 18
> migrations and live data in `demo` and `safeline`, and it already runs
> database-per-company. Executing the tasks below would create a duplicate,
> conflicting schema.
>
> Four of its decisions are contradicted by the real design:
>
> | This plan | Actual decision |
> |---|---|
> | Greenfield snake_case tables | 84 existing PascalCase tables with data |
> | Single database + `company_id` | Database-per-company, connection is the tenant boundary |
> | RLS enforces read scope | Scope lives in sync rules; RLS not needed |
> | Introduce UUID primary keys | Client-generated ids already exist |
>
> It is kept, rather than deleted, because the test-harness pattern and the two
> POPIA assertions (no plaintext password column in `users`, none in
> `login_audit`) are reusable if a greenfield schema is ever built.
> **No task below should be executed.**

# PowerSync Schema + Sync Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author the clean snake_case PostgreSQL schema and PowerSync sync rules that every other sub-project of the PowerSync migration depends on.

**Architecture:** Idempotent, numbered SQL DDL files plus a PowerSync `sync_rules.yaml`. Each table is verified by SQL assertions run against a disposable Docker Postgres container. Tenant isolation is enforced at two chokepoints only: sync rules on the read path, Go handlers on the write path.

**Tech Stack:** PostgreSQL 15+, PowerSync (self-hosted Open Edition), Docker Compose, `psql`.

**Spec:** `docs/superpowers/specs/2026-09-05-powersync-migration-design.md`

## Global Constraints

- **NEVER connect to, read from, or modify the `Stat_Trac` production database.** All verification runs against the disposable container `stattrac_schema_test` on port `55432`. No task in this plan opens a connection to port 5432.
- All identifiers are `snake_case`. No double-quoted PascalCase identifiers anywhere.
- Every tenant-scoped table has `company_id uuid NOT NULL REFERENCES companies(id)`.
- Every table's primary key is `id uuid PRIMARY KEY` — client-generated, never `serial`/`identity`.
- Every migrated table has `legacy_id integer` for reconciliation against Stat_Trac. It is **nullable** (records born in the field have no legacy counterpart) and **not unique on its own** (uniqueness is per company).
- Every table has `created_at timestamptz NOT NULL DEFAULT now()` and `updated_at timestamptz NOT NULL DEFAULT now()`.
- Enum text values match the existing Dart domain strings **exactly** — they are consumed unchanged by `WoStatus`, `WoType`, `WoPriority`.
- `UserLog.UserLogPassword` has no counterpart in the new schema. Never add a column that stores a submitted password.
- DDL files are idempotent: `CREATE TABLE IF NOT EXISTS`, `DROP TYPE IF EXISTS` guards. Re-running the full build must succeed.
- This sub-project produces **files only**. It does not stand up a production database and does not implement the Go service.

---

## File Structure

```
backend/
  schema/
    000_extensions.sql        pgcrypto for gen_random_uuid()
    010_enums.sql             wo_status, wo_type, wo_priority, cert_type, patient_safe
    020_companies.sql         tenant registry
    030_users.sql             from "Admin", bcrypt, no plaintext
    040_assets.sql            from "Asset", incl. provisional
    050_work_orders.sql       from "Repair" + "RepairProgress"
    060_test_templates.sql    from "TestTemplateName" + "TestTemplate"
    070_certificates.sql      from "TestCertificate" + "TestOutput"
    080_pm_tasks.sql          from asset_pm_tasks + test equipment
    090_legacy_outbox.sql     write-back queue + login_audit
    100_replication.sql       publication for PowerSync WAL
  powersync/
    sync_rules.yaml           read-side tenant isolation
  test/
    docker-compose.test.yml   disposable postgres, port 55432
    run_schema_tests.sh       build + assert runner
    assertions/
      010_enums_test.sql
      020_companies_test.sql
      030_users_test.sql
      040_assets_test.sql
      050_work_orders_test.sql
      060_test_templates_test.sql
      070_certificates_test.sql
      080_pm_tasks_test.sql
      090_legacy_outbox_test.sql
      100_isolation_test.sql
```

Files are numbered so `cat backend/schema/*.sql | psql` applies them in dependency order.

---

### Task 1: Test harness

**Files:**
- Create: `backend/test/docker-compose.test.yml`
- Create: `backend/test/run_schema_tests.sh`
- Create: `backend/schema/000_extensions.sql`
- Test: `backend/test/assertions/000_extensions_test.sql`

**Interfaces:**
- Consumes: nothing
- Produces: `run_schema_tests.sh` — applies every `backend/schema/*.sql` in numeric order to a fresh container, then runs every `backend/test/assertions/*.sql`. Any assertion raising an exception fails the run with a non-zero exit code. All later tasks call this script unchanged.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/000_extensions_test.sql`:

```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    RAISE EXCEPTION 'pgcrypto extension is not installed';
  END IF;
  IF gen_random_uuid() IS NULL THEN
    RAISE EXCEPTION 'gen_random_uuid() did not return a value';
  END IF;
END $$;
```

- [ ] **Step 2: Create the disposable container definition**

`backend/test/docker-compose.test.yml`:

```yaml
services:
  schema_test_db:
    image: postgres:15
    container_name: stattrac_schema_test
    environment:
      POSTGRES_PASSWORD: schematest
      POSTGRES_DB: stattrac_schema_test
    ports:
      - "55432:5432"
    command: ["postgres", "-c", "wal_level=logical"]
```

`wal_level=logical` is required because Task 10 creates a publication for PowerSync replication.

- [ ] **Step 3: Write the runner**

`backend/test/run_schema_tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shopt -s nullglob   # an empty schema/ dir must apply nothing, not a literal glob
export PGPASSWORD=schematest
PSQL="psql -h localhost -p 55432 -U postgres -d stattrac_schema_test -v ON_ERROR_STOP=1 -q"

docker compose -f "$HERE/docker-compose.test.yml" down -v >/dev/null 2>&1 || true
docker compose -f "$HERE/docker-compose.test.yml" up -d

echo "waiting for postgres..."
for _ in $(seq 1 30); do
  if $PSQL -c 'SELECT 1' >/dev/null 2>&1; then break; fi
  sleep 1
done

echo "applying schema..."
for f in "$HERE"/../schema/*.sql; do
  echo "  $(basename "$f")"
  $PSQL -f "$f"
done

echo "running assertions..."
for f in "$HERE"/assertions/*.sql; do
  echo "  $(basename "$f")"
  $PSQL -f "$f"
done

echo "ALL SCHEMA TESTS PASSED"
docker compose -f "$HERE/docker-compose.test.yml" down -v >/dev/null 2>&1
```

- [ ] **Step 4: Run it to verify it fails**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL — `000_extensions.sql` does not exist yet, so the glob applies nothing and the assertion raises `pgcrypto extension is not installed`.

- [ ] **Step 5: Write the minimal DDL**

`backend/schema/000_extensions.sql`:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 7: Commit**

```bash
git add backend/test backend/schema/000_extensions.sql
git commit -m "feat(schema): add disposable schema test harness and pgcrypto extension"
```

---

### Task 2: Enums

**Files:**
- Create: `backend/schema/010_enums.sql`
- Test: `backend/test/assertions/010_enums_test.sql`

**Interfaces:**
- Consumes: Task 1's runner
- Produces: types `wo_status`, `wo_type`, `wo_priority`, `cert_type`, `patient_safe`, used by Task 6 (work_orders) and Task 8 (certificates).

The values below are copied from the Dart domain layer and the legacy integer mappings in `2-Production-Database.md`. They must not be renamed — the Flutter `WoStatus`, `WoType` and `WoPriority` enums parse these strings directly.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/010_enums_test.sql`:

```sql
DO $$
DECLARE
  expected text[];
  actual   text[];
BEGIN
  expected := ARRAY['created','assigned','accepted','en_route','on_site',
                    'in_progress','paused','awaiting_parts','completed',
                    'reviewed','closed','cancelled','rejected','reopened'];
  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder) INTO actual
    FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
   WHERE t.typname = 'wo_status';
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'wo_status mismatch: %', actual;
  END IF;

  expected := ARRAY['CM','PM','INS','INST','DEC','UPG'];
  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder) INTO actual
    FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
   WHERE t.typname = 'wo_type';
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'wo_type mismatch: %', actual;
  END IF;

  expected := ARRAY['P1','P2','P3','P4'];
  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder) INTO actual
    FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
   WHERE t.typname = 'wo_priority';
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'wo_priority mismatch: %', actual;
  END IF;

  expected := ARRAY['test_ovp','qa','commission'];
  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder) INTO actual
    FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
   WHERE t.typname = 'cert_type';
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'cert_type mismatch: %', actual;
  END IF;

  expected := ARRAY['non_compliant','compliant','incomplete'];
  SELECT array_agg(e.enumlabel ORDER BY e.enumsortorder) INTO actual
    FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
   WHERE t.typname = 'patient_safe';
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'patient_safe mismatch: %', actual;
  END IF;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `wo_status mismatch: <NULL>`

- [ ] **Step 3: Write the DDL**

`backend/schema/010_enums.sql`:

```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wo_status') THEN
    CREATE TYPE wo_status AS ENUM (
      'created','assigned','accepted','en_route','on_site',
      'in_progress','paused','awaiting_parts','completed',
      'reviewed','closed','cancelled','rejected','reopened');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wo_type') THEN
    CREATE TYPE wo_type AS ENUM ('CM','PM','INS','INST','DEC','UPG');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wo_priority') THEN
    CREATE TYPE wo_priority AS ENUM ('P1','P2','P3','P4');
  END IF;

  -- legacy TestCertType: 1=Test/OVP, 2=QA, 3=Commission
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cert_type') THEN
    CREATE TYPE cert_type AS ENUM ('test_ovp','qa','commission');
  END IF;

  -- legacy TestCertPatientSafe: 0=Non-Compliant, 1=Compliant, 2=Incomplete
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'patient_safe') THEN
    CREATE TYPE patient_safe AS ENUM ('non_compliant','compliant','incomplete');
  END IF;
END $$;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/010_enums.sql backend/test/assertions/010_enums_test.sql
git commit -m "feat(schema): add domain enums matching Dart domain strings"
```

---

### Task 3: Companies

**Files:**
- Create: `backend/schema/020_companies.sql`
- Test: `backend/test/assertions/020_companies_test.sql`

**Interfaces:**
- Consumes: `000_extensions.sql`
- Produces: `companies(id uuid PK, name text, legacy_db_name text, is_active boolean, created_at, updated_at)`. Every other tenant-scoped table references `companies(id)`.

`legacy_db_name` records which legacy tenant database (`Stat_Trac`, etc.) a company was migrated from — the mirror job in sub-project 2 needs it.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/020_companies_test.sql`:

```sql
DO $$
DECLARE c1 uuid;
BEGIN
  INSERT INTO companies (name, legacy_db_name)
       VALUES ('Acme Health', 'Stat_Trac')
    RETURNING id INTO c1;

  IF c1 IS NULL THEN
    RAISE EXCEPTION 'companies.id was not defaulted';
  END IF;

  -- name must be unique
  BEGIN
    INSERT INTO companies (name) VALUES ('Acme Health');
    RAISE EXCEPTION 'duplicate company name was allowed';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  IF (SELECT is_active FROM companies WHERE id = c1) IS NOT TRUE THEN
    RAISE EXCEPTION 'is_active did not default to true';
  END IF;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "companies" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/020_companies.sql`:

```sql
CREATE TABLE IF NOT EXISTS companies (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL UNIQUE,
  legacy_db_name text,
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/020_companies.sql backend/test/assertions/020_companies_test.sql
git commit -m "feat(schema): add companies tenant registry"
```

---

### Task 4: Users

**Files:**
- Create: `backend/schema/030_users.sql`
- Test: `backend/test/assertions/030_users_test.sql`

**Interfaces:**
- Consumes: `companies(id)`
- Produces: `users(id uuid PK, company_id uuid, legacy_id integer, email citext, password_hash text, full_name text, role text, is_technician boolean, is_active boolean, can_view_all_work_orders boolean, region text, base_hospital text, cellphone text, created_at, updated_at)`. Task 6 (work_orders, work_order_progress) and Task 8 (certificates) reference `users(id)`.

Mapping from legacy `"Admin"`: `UserName` (an email address) → `email`; `UserContactName` → `full_name`; `UserTechnician = 1` → `is_technician`; `UserActive = 1` → `is_active`; `UserAssignedWO = 1` → `can_view_all_work_orders = false`; `UserRegion` → `region`.

`password_hash` holds a bcrypt digest. **No plain-text password column exists, and none may be added.**

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/030_users_test.sql`:

```sql
DO $$
DECLARE c1 uuid; u1 uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('UserTest Co') RETURNING id INTO c1;

  INSERT INTO users (company_id, legacy_id, email, password_hash, full_name, role)
       VALUES (c1, 35, 'Fritz@Example.CO.ZA', '$2a$10$abcdefghijklmnopqrstuv', 'Mauritz Britz', 'technician')
    RETURNING id INTO u1;

  -- email is case-insensitive
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'fritz@example.co.za') THEN
    RAISE EXCEPTION 'email lookup is not case-insensitive';
  END IF;

  -- email unique within a company
  BEGIN
    INSERT INTO users (company_id, email, password_hash, full_name)
    VALUES (c1, 'fritz@example.co.za', 'x', 'Dup');
    RAISE EXCEPTION 'duplicate email within company was allowed';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  -- no column may store a plaintext password
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'users'
       AND column_name IN ('password','user_password','plaintext_password')
  ) THEN
    RAISE EXCEPTION 'users has a plaintext password column';
  END IF;

  IF (SELECT can_view_all_work_orders FROM users WHERE id = u1) IS NOT FALSE THEN
    RAISE EXCEPTION 'can_view_all_work_orders should default false';
  END IF;

  DELETE FROM companies WHERE id = c1;
  IF EXISTS (SELECT 1 FROM users WHERE id = u1) THEN
    RAISE EXCEPTION 'users row survived company delete; cascade missing';
  END IF;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "users" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/030_users.sql`:

```sql
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS users (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id               uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id                integer,
  email                    citext NOT NULL,
  password_hash            text NOT NULL,
  full_name                text NOT NULL,
  role                     text NOT NULL DEFAULT 'technician',
  is_technician            boolean NOT NULL DEFAULT true,
  is_active                boolean NOT NULL DEFAULT true,
  can_view_all_work_orders boolean NOT NULL DEFAULT false,
  region                   text,
  base_hospital            text,
  cellphone                text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_role_check
    CHECK (role IN ('technician','customer','admin'))
);

CREATE UNIQUE INDEX IF NOT EXISTS users_company_email_key
  ON users (company_id, email);
CREATE UNIQUE INDEX IF NOT EXISTS users_company_legacy_key
  ON users (company_id, legacy_id) WHERE legacy_id IS NOT NULL;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/030_users.sql backend/test/assertions/030_users_test.sql
git commit -m "feat(schema): add users with bcrypt hashes and no plaintext column"
```

---

### Task 5: Assets

**Files:**
- Create: `backend/schema/040_assets.sql`
- Test: `backend/test/assertions/040_assets_test.sql`

**Interfaces:**
- Consumes: `companies(id)`
- Produces: `assets(id uuid PK, company_id, legacy_id, serial_no, manufacturer, model, equipment_type, hospital, hospital_group, location, condition, barcode, is_active, is_condemned, is_provisional, next_service_date, last_service_date, created_at, updated_at)`. Task 6 (work_orders), Task 8 (certificates) and Task 9 (asset_pm_tasks) reference `assets(id)`.

Per the spec's provisional-assets section: a provisional record gets a real UUID at creation, so no `server_id`-style nullable identity column is needed. `is_provisional` is a review-queue marker only.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/040_assets_test.sql`:

```sql
DO $$
DECLARE c1 uuid; a1 uuid; a2 uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('AssetTest Co') RETURNING id INTO c1;

  INSERT INTO assets (company_id, legacy_id, serial_no, equipment_type, hospital)
       VALUES (c1, 4711, 'SN-001', 'Infusion Pump', 'Acme Hospital')
    RETURNING id INTO a1;

  IF (SELECT is_provisional FROM assets WHERE id = a1) IS NOT FALSE THEN
    RAISE EXCEPTION 'is_provisional should default false';
  END IF;

  -- a provisional asset has a real key and no legacy_id
  INSERT INTO assets (company_id, serial_no, equipment_type, is_provisional)
       VALUES (c1, 'SN-FIELD-002', 'Defibrillator', true)
    RETURNING id INTO a2;

  IF a2 IS NULL THEN
    RAISE EXCEPTION 'provisional asset did not receive a primary key';
  END IF;
  IF (SELECT legacy_id FROM assets WHERE id = a2) IS NOT NULL THEN
    RAISE EXCEPTION 'provisional asset should have null legacy_id';
  END IF;

  -- legacy_id unique per company, but multiple NULLs allowed
  BEGIN
    INSERT INTO assets (company_id, legacy_id, serial_no)
    VALUES (c1, 4711, 'SN-DUP');
    RAISE EXCEPTION 'duplicate legacy_id within company was allowed';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "assets" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/040_assets.sql`:

```sql
CREATE TABLE IF NOT EXISTS assets (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id         integer,
  serial_no         text,
  manufacturer      text,
  model             text,
  equipment_type    text,
  hospital          text,
  hospital_group    text,
  location          text,
  condition         text,
  barcode           text,
  is_active         boolean NOT NULL DEFAULT true,
  is_condemned      boolean NOT NULL DEFAULT false,
  is_provisional    boolean NOT NULL DEFAULT false,
  next_service_date date,
  last_service_date date,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS assets_company_legacy_key
  ON assets (company_id, legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS assets_company_hospital_idx
  ON assets (company_id, hospital);
CREATE INDEX IF NOT EXISTS assets_company_barcode_idx
  ON assets (company_id, barcode);
CREATE INDEX IF NOT EXISTS assets_provisional_idx
  ON assets (company_id) WHERE is_provisional;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/040_assets.sql backend/test/assertions/040_assets_test.sql
git commit -m "feat(schema): add assets with provisional support"
```

---

### Task 6: Work orders and progress

**Files:**
- Create: `backend/schema/050_work_orders.sql`
- Test: `backend/test/assertions/050_work_orders_test.sql`

**Interfaces:**
- Consumes: `companies(id)`, `assets(id)`, `users(id)`, enums from Task 2
- Produces: `work_orders(id, company_id, legacy_id, asset_id, wo_number, type wo_type, priority wo_priority, status wo_status, symptom_description, resolution_narrative, root_cause_code, assigned_user_id, hospital, location, scheduled_at, started_at, completed_at, created_at, updated_at)` and `work_order_progress(id, company_id, work_order_id, asset_id, status wo_status, work_done, hours, technician_name, technician_id, occurred_at, created_at)`.

`work_order_progress` replaces `"RepairProgress"` and its `ProgessTrackID` typo with a correctly spelled `work_order_id`.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/050_work_orders_test.sql`:

```sql
DO $$
DECLARE c1 uuid; a1 uuid; u1 uuid; w1 uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('WoTest Co') RETURNING id INTO c1;
  INSERT INTO assets (company_id, serial_no) VALUES (c1, 'SN-WO') RETURNING id INTO a1;
  INSERT INTO users (company_id, email, password_hash, full_name)
       VALUES (c1, 'tech@wo.test', 'x', 'Tech') RETURNING id INTO u1;

  INSERT INTO work_orders (company_id, asset_id, assigned_user_id,
                           type, priority, status, symptom_description)
       VALUES (c1, a1, u1, 'CM', 'P1', 'in_progress', 'Pump alarms intermittently')
    RETURNING id INTO w1;

  IF (SELECT status FROM work_orders WHERE id = w1) <> 'in_progress' THEN
    RAISE EXCEPTION 'status did not persist';
  END IF;

  -- invalid enum value must be rejected
  BEGIN
    INSERT INTO work_orders (company_id, asset_id, type, priority, status)
    VALUES (c1, a1, 'CM', 'P1', 'not_a_status');
    RAISE EXCEPTION 'invalid wo_status was accepted';
  EXCEPTION WHEN invalid_text_representation THEN
    NULL;
  END;

  INSERT INTO work_order_progress (company_id, work_order_id, asset_id,
                                   status, work_done, hours, technician_name)
       VALUES (c1, w1, a1, 'completed', 'Replaced sensor', 1.5, 'Tech');

  IF (SELECT count(*) FROM work_order_progress WHERE work_order_id = w1) <> 1 THEN
    RAISE EXCEPTION 'progress row not written';
  END IF;

  DELETE FROM work_orders WHERE id = w1;
  IF EXISTS (SELECT 1 FROM work_order_progress WHERE work_order_id = w1) THEN
    RAISE EXCEPTION 'progress row survived work order delete; cascade missing';
  END IF;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "work_orders" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/050_work_orders.sql`:

```sql
CREATE TABLE IF NOT EXISTS work_orders (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id           uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id            integer,
  asset_id             uuid REFERENCES assets(id) ON DELETE SET NULL,
  wo_number            text,
  type                 wo_type NOT NULL,
  priority             wo_priority NOT NULL DEFAULT 'P3',
  status               wo_status NOT NULL DEFAULT 'created',
  symptom_description  text,
  resolution_narrative text,
  root_cause_code      text,
  assigned_user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  hospital             text,
  location             text,
  scheduled_at         timestamptz,
  started_at           timestamptz,
  completed_at         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS work_orders_company_legacy_key
  ON work_orders (company_id, legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS work_orders_company_status_idx
  ON work_orders (company_id, status);
CREATE INDEX IF NOT EXISTS work_orders_assigned_idx
  ON work_orders (company_id, assigned_user_id);

CREATE TABLE IF NOT EXISTS work_order_progress (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id       integer,
  work_order_id   uuid NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
  asset_id        uuid REFERENCES assets(id) ON DELETE SET NULL,
  status          wo_status,
  work_done       text,
  hours           numeric(6,2),
  technician_name text,
  technician_id   uuid REFERENCES users(id) ON DELETE SET NULL,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS work_order_progress_wo_idx
  ON work_order_progress (work_order_id);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/050_work_orders.sql backend/test/assertions/050_work_orders_test.sql
git commit -m "feat(schema): add work_orders and work_order_progress"
```

---

### Task 7: Test templates

**Files:**
- Create: `backend/schema/060_test_templates.sql`
- Test: `backend/test/assertions/060_test_templates_test.sql`

**Interfaces:**
- Consumes: `companies(id)`, `cert_type`
- Produces: `test_templates(id, company_id, legacy_id, name, cert_name, type cert_type, is_active, created_at, updated_at)` and `test_template_items(id, company_id, legacy_id, template_id, description_id, description, expected_value, actual_value_template, note, sort_order, created_at, updated_at)`.

`actual_value_template` carries legacy `TestTempActualValue`. The sentinel `'-'` means no actual reading is required — the Flutter `noActualRequired` getter already depends on this exact value, so it is preserved verbatim rather than normalised to NULL.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/060_test_templates_test.sql`:

```sql
DO $$
DECLARE c1 uuid; t1 uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('TmplTest Co') RETURNING id INTO c1;

  INSERT INTO test_templates (company_id, legacy_id, name, cert_name, type)
       VALUES (c1, 12, 'Electrical Safety Test IEC 62353', 'OVP', 'test_ovp')
    RETURNING id INTO t1;

  INSERT INTO test_template_items
    (company_id, template_id, description_id, description, expected_value, actual_value_template, sort_order)
  VALUES
    (c1, t1, 'SECTION-A', 'Earth resistance', '< 0.3 ohm', '0.0', 1),
    (c1, t1, 'SECTION-A', 'Visual inspection', 'Pass',      '-',   2);

  -- the '-' sentinel must survive verbatim
  IF (SELECT actual_value_template FROM test_template_items
       WHERE template_id = t1 AND sort_order = 2) <> '-' THEN
    RAISE EXCEPTION 'the ''-'' sentinel was not preserved verbatim';
  END IF;

  IF (SELECT count(*) FROM test_template_items WHERE template_id = t1) <> 2 THEN
    RAISE EXCEPTION 'template items not written';
  END IF;

  DELETE FROM test_templates WHERE id = t1;
  IF EXISTS (SELECT 1 FROM test_template_items WHERE template_id = t1) THEN
    RAISE EXCEPTION 'items survived template delete; cascade missing';
  END IF;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "test_templates" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/060_test_templates.sql`:

```sql
CREATE TABLE IF NOT EXISTS test_templates (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id  integer,
  name       text NOT NULL,
  cert_name  text,
  type       cert_type NOT NULL,
  is_active  boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS test_templates_company_legacy_key
  ON test_templates (company_id, legacy_id) WHERE legacy_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS test_template_items (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id             integer,
  template_id           uuid NOT NULL REFERENCES test_templates(id) ON DELETE CASCADE,
  description_id        text,
  description           text NOT NULL,
  expected_value        text,
  -- legacy TestTempActualValue; '-' means no actual reading required
  actual_value_template text,
  note                  text,
  sort_order            integer NOT NULL DEFAULT 0,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS test_template_items_template_idx
  ON test_template_items (template_id, sort_order);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/060_test_templates.sql backend/test/assertions/060_test_templates_test.sql
git commit -m "feat(schema): add test_templates and test_template_items"
```

---

### Task 8: Certificates and outputs

**Files:**
- Create: `backend/schema/070_certificates.sql`
- Test: `backend/test/assertions/070_certificates_test.sql`

**Interfaces:**
- Consumes: `companies(id)`, `assets(id)`, `users(id)`, `test_templates(id)`, `cert_type`, `patient_safe`
- Produces: `certificates(id, company_id, legacy_id, asset_id, template_id, type cert_type, technician_id, technician_name, tested_on, doc_no, client_name_signature, requires_client_signature, notes, patient_safe, template_name, service_description, service_interval, service_type, service_pm_task_id, total_tests, total_passed, created_at, updated_at)` and `certificate_outputs(id, company_id, certificate_id, asset_id, description_id, description, expected_value, actual_value, note, result, created_at, updated_at)`.

`certificate_outputs.note` is legacy `"TestNote"` (singular). The legacy `"TestNotes"` column serves a different purpose and is **not** mapped here.

Legacy `TestPass`/`TestFail`/`TestNA` were three mutually exclusive integer flags. They collapse into a single `result` column with a CHECK constraint, which makes the invalid "pass and fail simultaneously" state unrepresentable.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/070_certificates_test.sql`:

```sql
DO $$
DECLARE c1 uuid; a1 uuid; u1 uuid; t1 uuid; cert uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('CertTest Co') RETURNING id INTO c1;
  INSERT INTO assets (company_id, serial_no) VALUES (c1, 'SN-CERT') RETURNING id INTO a1;
  INSERT INTO users (company_id, email, password_hash, full_name)
       VALUES (c1, 'tech@cert.test', 'x', 'Tech') RETURNING id INTO u1;
  INSERT INTO test_templates (company_id, name, type)
       VALUES (c1, 'Electrical Safety', 'test_ovp') RETURNING id INTO t1;

  INSERT INTO certificates (company_id, asset_id, template_id, type,
                            technician_id, tested_on, patient_safe,
                            requires_client_signature, client_name_signature)
       VALUES (c1, a1, t1, 'test_ovp', u1, current_date, 'compliant',
               true, 'Sister Jones')
    RETURNING id INTO cert;

  -- born in the field: no legacy id until write-back assigns one
  IF (SELECT legacy_id FROM certificates WHERE id = cert) IS NOT NULL THEN
    RAISE EXCEPTION 'new certificate should have null legacy_id';
  END IF;

  INSERT INTO certificate_outputs
    (company_id, certificate_id, asset_id, description_id, description,
     expected_value, actual_value, note, result)
  VALUES
    (c1, cert, a1, 'SECTION-A', 'Earth resistance', '< 0.3 ohm', '0.12', 'from template', 'pass'),
    (c1, cert, a1, 'SECTION-A', 'Leakage current', '< 500 uA',  '310',  NULL, 'pass'),
    (c1, cert, a1, 'SECTION-B', 'Battery test',    'Pass',       NULL,  NULL, 'na');

  IF (SELECT count(*) FROM certificate_outputs WHERE certificate_id = cert) <> 3 THEN
    RAISE EXCEPTION 'outputs not written';
  END IF;

  -- result is constrained
  BEGIN
    INSERT INTO certificate_outputs (company_id, certificate_id, description, result)
    VALUES (c1, cert, 'Bogus', 'maybe');
    RAISE EXCEPTION 'invalid result value was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  DELETE FROM certificates WHERE id = cert;
  IF EXISTS (SELECT 1 FROM certificate_outputs WHERE certificate_id = cert) THEN
    RAISE EXCEPTION 'outputs survived certificate delete; cascade missing';
  END IF;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "certificates" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/070_certificates.sql`:

```sql
CREATE TABLE IF NOT EXISTS certificates (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id                uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id                 integer,
  asset_id                  uuid REFERENCES assets(id) ON DELETE SET NULL,
  template_id               uuid REFERENCES test_templates(id) ON DELETE SET NULL,
  type                      cert_type NOT NULL,
  technician_id             uuid REFERENCES users(id) ON DELETE SET NULL,
  technician_name           text,
  tested_on                 date NOT NULL DEFAULT current_date,
  doc_no                    text,
  -- legacy TestType = 1 meant "client signature required"
  requires_client_signature boolean NOT NULL DEFAULT false,
  client_name_signature     text,
  notes                     text,
  patient_safe              patient_safe,
  template_name             text,
  service_description       text,
  service_interval          text,
  service_type              text,
  service_pm_task_id        uuid,
  total_tests               integer NOT NULL DEFAULT 0,
  total_passed              integer NOT NULL DEFAULT 0,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS certificates_company_legacy_key
  ON certificates (company_id, legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS certificates_company_tech_idx
  ON certificates (company_id, technician_id, tested_on DESC);

CREATE TABLE IF NOT EXISTS certificate_outputs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id      integer,
  certificate_id uuid NOT NULL REFERENCES certificates(id) ON DELETE CASCADE,
  asset_id       uuid REFERENCES assets(id) ON DELETE SET NULL,
  description_id text,
  description    text NOT NULL,
  expected_value text,
  actual_value   text,
  -- legacy "TestNote" (singular). "TestNotes" is a different column, not mapped.
  note           text,
  result         text,
  sort_order     integer NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT certificate_outputs_result_check
    CHECK (result IS NULL OR result IN ('pass','fail','na'))
);

CREATE INDEX IF NOT EXISTS certificate_outputs_cert_idx
  ON certificate_outputs (certificate_id, description_id, sort_order);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/070_certificates.sql backend/test/assertions/070_certificates_test.sql
git commit -m "feat(schema): add certificates and certificate_outputs"
```

---

### Task 9: PM tasks and test equipment

**Files:**
- Create: `backend/schema/080_pm_tasks.sql`
- Test: `backend/test/assertions/080_pm_tasks_test.sql`

**Interfaces:**
- Consumes: `companies(id)`, `assets(id)`, `certificates(id)`
- Produces: `asset_pm_tasks(id, company_id, legacy_id, asset_id, description, schedule_date, interval_value, interval_type, is_active, created_at, updated_at)`, `test_equipment(id, company_id, legacy_id, name, equipment_type, serial_no, cal_date, cal_due_date, is_active, ...)` and `certificate_equipment(id, company_id, certificate_id, equipment_id, equipment_type, cal_due_date, created_at)`.

`certificates.service_pm_task_id` (Task 8) references `asset_pm_tasks(id)`; the FK is added here because the referenced table is created in this task.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/080_pm_tasks_test.sql`:

```sql
DO $$
DECLARE c1 uuid; a1 uuid; p1 uuid; e1 uuid; t1 uuid; cert uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('PmTest Co') RETURNING id INTO c1;
  INSERT INTO assets (company_id, serial_no) VALUES (c1, 'SN-PM') RETURNING id INTO a1;

  INSERT INTO asset_pm_tasks (company_id, legacy_id, asset_id, description,
                              schedule_date, interval_value, interval_type)
       VALUES (c1, 901, a1, '6 Monthly Service', current_date, '6', 'months')
    RETURNING id INTO p1;

  INSERT INTO test_equipment (company_id, name, equipment_type, serial_no, cal_due_date)
       VALUES (c1, 'Fluke ESA615', 'Analyser', 'FL-001', current_date + 30)
    RETURNING id INTO e1;

  INSERT INTO test_templates (company_id, name, type)
       VALUES (c1, 'PM Template', 'qa') RETURNING id INTO t1;
  INSERT INTO certificates (company_id, asset_id, template_id, type, service_pm_task_id)
       VALUES (c1, a1, t1, 'qa', p1) RETURNING id INTO cert;

  -- the FK from certificates to asset_pm_tasks must be enforced
  BEGIN
    UPDATE certificates SET service_pm_task_id = gen_random_uuid() WHERE id = cert;
    RAISE EXCEPTION 'certificates.service_pm_task_id FK is not enforced';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  INSERT INTO certificate_equipment (company_id, certificate_id, equipment_id,
                                     equipment_type, cal_due_date)
       VALUES (c1, cert, e1, 'Analyser', current_date + 30);

  IF (SELECT count(*) FROM certificate_equipment WHERE certificate_id = cert) <> 1 THEN
    RAISE EXCEPTION 'certificate_equipment row not written';
  END IF;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "asset_pm_tasks" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/080_pm_tasks.sql`:

```sql
CREATE TABLE IF NOT EXISTS asset_pm_tasks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id      integer,
  asset_id       uuid REFERENCES assets(id) ON DELETE CASCADE,
  description    text,
  schedule_date  date,
  interval_value text,
  interval_type  text,
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS asset_pm_tasks_company_legacy_key
  ON asset_pm_tasks (company_id, legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS asset_pm_tasks_asset_idx
  ON asset_pm_tasks (asset_id) WHERE is_active;

ALTER TABLE certificates
  DROP CONSTRAINT IF EXISTS certificates_service_pm_task_fk;
ALTER TABLE certificates
  ADD CONSTRAINT certificates_service_pm_task_fk
  FOREIGN KEY (service_pm_task_id) REFERENCES asset_pm_tasks(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS test_equipment (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  legacy_id      integer,
  name           text NOT NULL,
  equipment_type text,
  serial_no      text,
  cal_date       date,
  cal_due_date   date,
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS test_equipment_company_legacy_key
  ON test_equipment (company_id, legacy_id) WHERE legacy_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS certificate_equipment (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  certificate_id uuid NOT NULL REFERENCES certificates(id) ON DELETE CASCADE,
  equipment_id   uuid REFERENCES test_equipment(id) ON DELETE SET NULL,
  equipment_type text,
  cal_due_date   date,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS certificate_equipment_cert_idx
  ON certificate_equipment (certificate_id);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/080_pm_tasks.sql backend/test/assertions/080_pm_tasks_test.sql
git commit -m "feat(schema): add asset_pm_tasks, test_equipment and certificate_equipment"
```

---

### Task 10: Legacy outbox and login audit

**Files:**
- Create: `backend/schema/090_legacy_outbox.sql`
- Test: `backend/test/assertions/090_legacy_outbox_test.sql`

**Interfaces:**
- Consumes: `companies(id)`
- Produces: `legacy_outbox(id, company_id, entity, entity_id uuid, op, payload jsonb, status, attempts, last_error, available_at, created_at, updated_at)` and `login_audit(id, company_id, user_id, email_attempted, ip_address, client_type, client_version, client_os, was_successful, occurred_at)`.

Sub-project 2's Go write-back worker claims rows with `SELECT ... FOR UPDATE SKIP LOCKED WHERE status = 'pending' AND available_at <= now()`. The partial index below serves that query.

`login_audit` deliberately has **no password column** — the assertion enforces this permanently.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/090_legacy_outbox_test.sql`:

```sql
DO $$
DECLARE c1 uuid; o1 uuid;
BEGIN
  INSERT INTO companies (name) VALUES ('OutboxTest Co') RETURNING id INTO c1;

  INSERT INTO legacy_outbox (company_id, entity, entity_id, op, payload)
       VALUES (c1, 'certificate', gen_random_uuid(), 'insert', '{"a":1}'::jsonb)
    RETURNING id INTO o1;

  IF (SELECT status FROM legacy_outbox WHERE id = o1) <> 'pending' THEN
    RAISE EXCEPTION 'status should default to pending';
  END IF;
  IF (SELECT attempts FROM legacy_outbox WHERE id = o1) <> 0 THEN
    RAISE EXCEPTION 'attempts should default to 0';
  END IF;

  BEGIN
    INSERT INTO legacy_outbox (company_id, entity, entity_id, op, status)
    VALUES (c1, 'certificate', gen_random_uuid(), 'insert', 'bogus');
    RAISE EXCEPTION 'invalid outbox status was accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;

  -- the worker's claim query must be satisfiable
  PERFORM 1 FROM legacy_outbox
    WHERE status = 'pending' AND available_at <= now()
    FOR UPDATE SKIP LOCKED;

  INSERT INTO login_audit (company_id, email_attempted, ip_address,
                           client_type, client_os, was_successful)
       VALUES (c1, 'fritz@example.co.za', '10.0.0.1',
               'StatTrac Technical App', 'Android', false);

  -- no password may ever be stored in the audit trail
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'login_audit'
       AND column_name ILIKE '%password%'
  ) THEN
    RAISE EXCEPTION 'login_audit has a password column; POPIA violation';
  END IF;

  DELETE FROM companies WHERE id = c1;
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `relation "legacy_outbox" does not exist`

- [ ] **Step 3: Write the DDL**

`backend/schema/090_legacy_outbox.sql`:

```sql
CREATE TABLE IF NOT EXISTS legacy_outbox (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id   uuid NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  entity       text NOT NULL,
  entity_id    uuid NOT NULL,
  op           text NOT NULL,
  payload      jsonb,
  status       text NOT NULL DEFAULT 'pending',
  attempts     integer NOT NULL DEFAULT 0,
  last_error   text,
  available_at timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT legacy_outbox_status_check
    CHECK (status IN ('pending','in_progress','done','dead')),
  CONSTRAINT legacy_outbox_op_check
    CHECK (op IN ('insert','update','delete'))
);

CREATE INDEX IF NOT EXISTS legacy_outbox_claim_idx
  ON legacy_outbox (available_at)
  WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS login_audit (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid REFERENCES companies(id) ON DELETE SET NULL,
  user_id         uuid REFERENCES users(id) ON DELETE SET NULL,
  email_attempted citext,
  ip_address      inet,
  client_type     text,
  client_version  text,
  client_os       text,
  was_successful  boolean NOT NULL,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS login_audit_occurred_idx
  ON login_audit (occurred_at DESC);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 5: Commit**

```bash
git add backend/schema/090_legacy_outbox.sql backend/test/assertions/090_legacy_outbox_test.sql
git commit -m "feat(schema): add legacy_outbox and login_audit without password column"
```

---

### Task 11: Replication publication and sync rules

**Files:**
- Create: `backend/schema/100_replication.sql`
- Create: `backend/powersync/sync_rules.yaml`
- Test: `backend/test/assertions/100_isolation_test.sql`

**Interfaces:**
- Consumes: every table from Tasks 3–10
- Produces: publication `powersync` (the WAL source PowerSync replicates from) and `sync_rules.yaml` (the read-side tenant isolation mechanism).

The isolation assertion proves the predicate each sync-rule query relies on: filtering by `company_id` returns one company's rows and never another's. If this assertion ever fails, the sync rules leak across tenants.

`legacy_outbox` and `login_audit` are deliberately excluded from the publication — they are server-side concerns and must never reach a device.

- [ ] **Step 1: Write the failing assertion**

`backend/test/assertions/100_isolation_test.sql`:

```sql
DO $$
DECLARE c1 uuid; c2 uuid; n integer;
BEGIN
  INSERT INTO companies (name) VALUES ('Isolation A') RETURNING id INTO c1;
  INSERT INTO companies (name) VALUES ('Isolation B') RETURNING id INTO c2;

  INSERT INTO assets (company_id, serial_no) VALUES (c1, 'A-1'), (c1, 'A-2');
  INSERT INTO assets (company_id, serial_no) VALUES (c2, 'B-1');

  SELECT count(*) INTO n FROM assets WHERE company_id = c1;
  IF n <> 2 THEN RAISE EXCEPTION 'company A should see exactly 2 assets, saw %', n; END IF;

  SELECT count(*) INTO n FROM assets WHERE company_id = c1 AND serial_no = 'B-1';
  IF n <> 0 THEN RAISE EXCEPTION 'company A can see company B rows'; END IF;

  -- the publication PowerSync replicates from must exist
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    RAISE EXCEPTION 'publication "powersync" does not exist';
  END IF;

  -- server-side tables must never be published to devices
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'powersync'
       AND tablename IN ('legacy_outbox','login_audit')
  ) THEN
    RAISE EXCEPTION 'server-side table is published to devices';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'powersync' AND tablename = 'certificates'
  ) THEN
    RAISE EXCEPTION 'certificates is not published';
  END IF;

  DELETE FROM companies WHERE id IN (c1, c2);
END $$;
```

- [ ] **Step 2: Run tests to verify failure**

Run: `bash backend/test/run_schema_tests.sh`
Expected: FAIL with `publication "powersync" does not exist`

- [ ] **Step 3: Write the publication DDL**

`backend/schema/100_replication.sql`:

```sql
-- PowerSync replicates from this publication. Server-side tables
-- (legacy_outbox, login_audit) are deliberately excluded.
DROP PUBLICATION IF EXISTS powersync;
CREATE PUBLICATION powersync FOR TABLE
  companies,
  users,
  assets,
  work_orders,
  work_order_progress,
  test_templates,
  test_template_items,
  certificates,
  certificate_outputs,
  asset_pm_tasks,
  test_equipment,
  certificate_equipment;
```

- [ ] **Step 4: Write the sync rules**

`backend/powersync/sync_rules.yaml`:

```yaml
# Read-side tenant isolation. company_id comes from the JWT the Go
# service signs; it is never supplied by the client.
bucket_definitions:
  company_data:
    parameters: SELECT token_parameters.company_id AS company_id
    data:
      - SELECT * FROM assets              WHERE company_id = bucket.company_id
      - SELECT * FROM work_orders         WHERE company_id = bucket.company_id
      - SELECT * FROM work_order_progress WHERE company_id = bucket.company_id
      - SELECT * FROM test_templates      WHERE company_id = bucket.company_id
      - SELECT * FROM test_template_items WHERE company_id = bucket.company_id
      - SELECT * FROM certificates        WHERE company_id = bucket.company_id
      - SELECT * FROM certificate_outputs WHERE company_id = bucket.company_id
      - SELECT * FROM asset_pm_tasks      WHERE company_id = bucket.company_id
      - SELECT * FROM test_equipment      WHERE company_id = bucket.company_id
      - SELECT * FROM certificate_equipment WHERE company_id = bucket.company_id

  # The signed-in user's own profile only — never the company's user list.
  user_profile:
    parameters: SELECT token_parameters.user_id AS user_id
    data:
      - SELECT id, company_id, email, full_name, role, is_technician,
               can_view_all_work_orders, region, base_hospital
          FROM users WHERE id = bucket.user_id
```

Note that `users` is published for replication but exposed through a bucket restricted to the signed-in user — password hashes are never selected, and one technician cannot sync another's record.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash backend/test/run_schema_tests.sh`
Expected: `ALL SCHEMA TESTS PASSED`

- [ ] **Step 6: Verify the full build is idempotent**

Run: `bash backend/test/run_schema_tests.sh && bash backend/test/run_schema_tests.sh`
Expected: both runs print `ALL SCHEMA TESTS PASSED`

- [ ] **Step 7: Commit**

```bash
git add backend/schema/100_replication.sql backend/powersync/sync_rules.yaml \
        backend/test/assertions/100_isolation_test.sql
git commit -m "feat(schema): add powersync publication and tenant-scoped sync rules"
```

---

## Out of scope

Deferred to later sub-projects, per §8 of the spec:

- The Go service (auth, JWKS, `/api/data` handlers) — sub-project 4, built in a parallel workstream. This plan defines only the schema it writes to.
- The legacy mirror job and the write-back worker that drains `legacy_outbox` — sub-project 2.
- Flutter migration to the PowerSync SDK — sub-project 3.
- PDF generation replacing FastReport — sub-project 5.
- Data migration of existing Stat_Trac rows — requires the mirror job.
- Deploying any of this to the VPS. **This plan never connects to a production database.**

## Open items carried from the spec

- **PowerSync Open Edition licence terms for commercial self-hosted use are unverified.** Confirm before this schema is deployed anywhere real.
- Binary storage for photos and signatures (Go filesystem vs MinIO) is undecided; no table here models it.
- Password cutover (force reset vs one-time bcrypt migration) is deferred; `users.password_hash` supports either.
