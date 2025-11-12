-- =================================================================================
-- FIX USER ONBOARDING FLOW
-- =================================================================================
-- Purpose: Fix critical gaps in user signup and onboarding
-- GitHub Issues: #6, #7, #8 (Epic #9)
-- Date: November 11, 2025
-- 
-- Fixes:
--   1. Missing auth.users trigger to auto-create public.users record
--   2. Missing RLS INSERT policies for users and subscription tables
--   3. Missing automatic Free tier subscription assignment
--
-- Security: All triggers use SECURITY DEFINER with explicit schema qualification
-- =================================================================================

-- =================================================================================
-- SECTION 1: AUTO-CREATE USER PROFILE AND SUBSCRIPTION ON SIGNUP
-- =================================================================================

-- Function to handle new user creation
-- This runs when a new user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, pg_temp
LANGUAGE plpgsql
AS $$
DECLARE
    v_free_tier_id UUID;
    v_active_status_id UUID;
BEGIN
    -- Get Free tier and Active status IDs from lookup tables
    SELECT id INTO v_free_tier_id 
    FROM public.subscription_tier 
    WHERE slug = 'free';
    
    SELECT id INTO v_active_status_id 
    FROM public.subscription_status 
    WHERE slug = 'active';
    
    -- Validate lookup values exist
    IF v_free_tier_id IS NULL THEN
        RAISE EXCEPTION 'Free tier not found in subscription_tier table';
    END IF;
    
    IF v_active_status_id IS NULL THEN
        RAISE EXCEPTION 'Active status not found in subscription_status table';
    END IF;
    
    -- Create user profile record (non-PII only)
    -- PII is stored in auth.users.raw_user_meta_data
    INSERT INTO public.users (
        id,
        timezone,
        language,
        is_onboarded
    ) VALUES (
        NEW.id,
        'UTC',
        'en',
        false
    );
    
    -- Create Free tier subscription with default values
    INSERT INTO public.subscription (
        user_id,
        tier_id,
        status_id,
        syncs_used,
        ai_analyses_used,
        seo_submissions_used,
        cycle_start_date,
        cycle_end_date,
        next_billing_date,
        is_auto_renew_enabled
    ) VALUES (
        NEW.id,
        v_free_tier_id,
        v_active_status_id,
        0,
        0,
        0,
        NOW(),
        NOW() + INTERVAL '30 days',
        NOW() + INTERVAL '30 days',
        true
    );
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS 'Trigger function: Auto-creates user profile and Free tier subscription on signup';

-- Create trigger on auth.users INSERT
-- This automatically fires when Supabase Auth creates a new user
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

COMMENT ON TRIGGER on_auth_user_created ON auth.users IS 'Auto-creates public.users record and Free tier subscription on user signup';

-- =================================================================================
-- SECTION 2: ADD MISSING RLS INSERT POLICIES
-- =================================================================================

-- Users table: Allow users to insert their own profile
-- This is a fallback in case the trigger fails or for testing
CREATE POLICY users_insert_own ON public.users
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = id);

COMMENT ON POLICY users_insert_own ON public.users IS 
'Allow authenticated users to insert their own profile (fallback if trigger fails)';

-- Subscription table: Allow users to insert their own subscription
CREATE POLICY subscription_insert_own ON public.subscription
    FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = user_id);

COMMENT ON POLICY subscription_insert_own ON public.subscription IS 
'Allow authenticated users to create their own subscription record';

-- Subscription table: Allow users to update their own subscription
-- This is needed for upgrading/downgrading tiers and usage tracking
CREATE POLICY subscription_update_own ON public.subscription
    FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

COMMENT ON POLICY subscription_update_own ON public.subscription IS 
'Allow authenticated users to update their own subscription (tier upgrades, usage tracking)';

-- =================================================================================
-- SECTION 3: GRANTS AND PERMISSIONS
-- =================================================================================

-- Grant execute permission on trigger function to authenticated users
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;

-- =================================================================================
-- VERIFICATION AND MODULE INFO
-- =================================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ User Onboarding Fix - COMPLETE';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Changes Applied:';
    RAISE NOTICE '   1. Created handle_new_user() trigger function';
    RAISE NOTICE '   2. Created on_auth_user_created trigger on auth.users';
    RAISE NOTICE '   3. Added users_insert_own RLS policy';
    RAISE NOTICE '   4. Added subscription_insert_own RLS policy';
    RAISE NOTICE '   5. Added subscription_update_own RLS policy';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 Security:';
    RAISE NOTICE '   ✅ Trigger function uses SECURITY DEFINER with search_path';
    RAISE NOTICE '   ✅ RLS policies enforce user ownership (auth.uid())';
    RAISE NOTICE '   ✅ Lookup table IDs fetched dynamically (no hardcoded UUIDs)';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test this migration:';
    RAISE NOTICE '   1. Create test user: POST to /auth/v1/signup';
    RAISE NOTICE '   2. Verify public.users record created: SELECT * FROM users WHERE id = auth.uid()';
    RAISE NOTICE '   3. Verify subscription created: SELECT * FROM subscription WHERE user_id = auth.uid()';
    RAISE NOTICE '   4. Verify Free tier: SELECT tier_id FROM subscription JOIN subscription_tier ON tier_id = subscription_tier.id WHERE subscription_tier.slug = ''free''';
    RAISE NOTICE '   5. Test profile setup: POST to /functions/v1/auth-profile-setup';
    RAISE NOTICE '   6. Test quota check: SELECT check_quota(auth.uid(), ''syncs'')';
    RAISE NOTICE '';
    RAISE NOTICE '📖 Related Issues:';
    RAISE NOTICE '   - Issue #6: Missing auth.users trigger';
    RAISE NOTICE '   - Issue #7: Missing RLS INSERT policies';
    RAISE NOTICE '   - Issue #8: Missing subscription auto-assignment';
    RAISE NOTICE '   - Epic #9: Fix Critical User Onboarding Flow';
    RAISE NOTICE '';
END;
$$;
