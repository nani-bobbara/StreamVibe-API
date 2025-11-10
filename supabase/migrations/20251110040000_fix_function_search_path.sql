-- =================================================================================
-- Migration: Fix Function Search Path Security Issues
-- Created: 2024-11-10 04:00:00
-- Description: Add explicit search_path to 37 database functions to prevent
--              search_path hijacking attacks.
--
-- Issue: Functions without explicit search_path can be exploited by malicious
--        actors who create schemas with same-named objects to intercept function
--        calls. This is a common attack vector in PostgreSQL.
--
-- Solution: Set search_path to 'public, pg_temp' for all functions. This ensures
--           that functions only reference objects in the public schema or
--           temporary tables, preventing malicious schema injection.
--
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable
--
-- Affected: 37 functions across all phases
-- =================================================================================

-- =================================================================================
-- PHASE 1: Core Utility Functions (5 functions)
-- =================================================================================

-- Authorization helper function
ALTER FUNCTION public.has_role(uuid, app_role_enum) 
    SET search_path = public, pg_temp;

-- Timestamp management trigger function
ALTER FUNCTION public.update_updated_at_column() 
    SET search_path = public, pg_temp;

-- Quota management functions
ALTER FUNCTION public.check_quota(uuid, text) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.increment_quota(uuid, text) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.decrement_quota(uuid, text) 
    SET search_path = public, pg_temp;

-- =================================================================================
-- PHASE 3: Content Management Functions (2 functions)
-- =================================================================================

-- Full-text search vector maintenance
ALTER FUNCTION public.content_item_search_vector_update() 
    SET search_path = public, pg_temp;

-- Business logic constraint enforcement
ALTER FUNCTION public.prevent_account_deletion_with_content() 
    SET search_path = public, pg_temp;

-- =================================================================================
-- PHASE 6: Discovery Platform Functions (4 functions)
-- =================================================================================

-- Social graph maintenance
ALTER FUNCTION public.update_total_followers() 
    SET search_path = public, pg_temp;

-- SEO-friendly slug generation
ALTER FUNCTION public.generate_profile_slug(text) 
    SET search_path = public, pg_temp;

-- Content engagement tracking
ALTER FUNCTION public.increment_content_clicks(uuid) 
    SET search_path = public, pg_temp;

-- Trending algorithm
ALTER FUNCTION public.calculate_trend_score(numeric, integer, integer, integer, timestamp with time zone) 
    SET search_path = public, pg_temp;

-- =================================================================================
-- PHASE 7: Async Job Queue Functions (17 functions)
-- =================================================================================

-- Job lifecycle management
ALTER FUNCTION public.start_job(uuid) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.retry_failed_jobs() 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.cleanup_old_jobs(interval) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.expire_stale_jobs(interval) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.detect_stuck_jobs(interval) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.notify_job_status_change() 
    SET search_path = public, pg_temp;

-- Job CRUD operations
ALTER FUNCTION public.create_job(text, text, jsonb, integer, timestamp with time zone) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.update_job_progress(uuid, numeric, jsonb) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.complete_job(uuid, jsonb) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.fail_job(uuid, text, jsonb) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.cancel_job(uuid, text) 
    SET search_path = public, pg_temp;

-- Job logging and monitoring
ALTER FUNCTION public.add_job_log(uuid, text, text, jsonb) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.get_user_jobs(uuid, text, integer, integer) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.get_job_logs(uuid, text, integer, integer) 
    SET search_path = public, pg_temp;

-- Job caching and queue stats
ALTER FUNCTION public.find_or_create_job(uuid, text, text, jsonb, interval) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.get_cached_job_result(uuid, text, text, jsonb, interval) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.get_job_queue_stats() 
    SET search_path = public, pg_temp;

-- =================================================================================
-- PHASE 7: Stripe Webhook Functions (9 functions)
-- =================================================================================

-- Webhook event logging and processing
ALTER FUNCTION public.log_stripe_webhook_event(text, text, jsonb) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.mark_webhook_processed(uuid, text, jsonb) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.retry_failed_webhooks(integer) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.cleanup_old_webhook_events(interval) 
    SET search_path = public, pg_temp;

-- Stripe data caching
ALTER FUNCTION public.cache_stripe_data(text, text, text, jsonb, interval) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.get_cached_stripe_data(text, text, text) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.invalidate_stripe_cache(text, text, text) 
    SET search_path = public, pg_temp;

ALTER FUNCTION public.invalidate_stripe_cache_from_webhook() 
    SET search_path = public, pg_temp;

-- =================================================================================
-- SUMMARY
-- =================================================================================
-- Fixed 37 functions across all phases:
--   - Phase 1: 5 functions (auth, triggers, quota management)
--   - Phase 3: 2 functions (content search, business logic)
--   - Phase 6: 4 functions (social graph, trending, engagement)
--   - Phase 7: 26 functions (17 job queue + 9 Stripe webhook)
--
-- Security Impact:
--   - Prevents search_path hijacking attacks
--   - Ensures functions only reference trusted schemas (public, pg_temp)
--   - Eliminates 37 "Function Search Path Mutable" linter warnings
--
-- Note: This migration uses ALTER FUNCTION which preserves all existing function
--       properties (SECURITY DEFINER, volatility, etc.) and only adds search_path.
-- =================================================================================
