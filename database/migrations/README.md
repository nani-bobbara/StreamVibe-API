# Database Migrations

This folder will contain future database migration files.

## Current Status

**Initial Schema**: Already deployed via `database/schema.sql`

## Migration Naming Convention

```
<version>_<description>.sql

Examples:
- 002_add_user_bio_field.sql
- 003_optimize_content_indexes.sql
- 004_add_twitter_platform.sql
```

## How to Apply Migrations

```bash
# Option 1: Supabase CLI
supabase db push

# Option 2: SQL Editor
# Copy migration file content and execute in Supabase SQL Editor

# Option 3: Edge Function
# Create migration runner Edge Function (future)
```

## Migration Template

```sql
-- Migration: <Description>
-- Created: YYYY-MM-DD
-- Author: <Name>

BEGIN;

-- Your changes here
ALTER TABLE users ADD COLUMN bio TEXT;

-- Rollback instructions (comment):
-- ALTER TABLE users DROP COLUMN bio;

COMMIT;
```

## Rollback Strategy

1. Keep rollback SQL in comments
2. Test migrations on staging first
3. Backup database before major migrations
4. Use transactions (BEGIN/COMMIT)

## Best Practices

- ✅ Always use transactions
- ✅ Test on staging environment first
- ✅ Include rollback instructions
- ✅ Use `IF NOT EXISTS` for idempotency
- ✅ Add indexes CONCURRENTLY on production
- ❌ Never drop columns with data without backup
- ❌ Never remove indexes without analyzing impact
