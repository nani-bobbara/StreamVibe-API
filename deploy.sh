#!/bin/bash

# StreamVibe API Deployment Script
# This script deploys database migrations and Edge Functions to Supabase

set -e  # Exit on error

echo "🚀 StreamVibe API Deployment"
echo "=============================="
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed"
    echo "Install it with: brew install supabase/tap/supabase"
    exit 1
fi

echo "✅ Supabase CLI found"
echo ""

# Check if project is linked (either via .supabase/config.toml or SUPABASE_ACCESS_TOKEN in CI)
if [ ! -f ".supabase/config.toml" ] && [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
    echo "❌ Project not linked to Supabase"
    echo "Run: supabase link --project-ref YOUR_PROJECT_REF"
    echo "Or set SUPABASE_ACCESS_TOKEN environment variable in CI/CD"
    exit 1
fi

# Check project_id in config.toml
if [ -f "supabase/config.toml" ]; then
    PROJECT_ID=$(grep '^project_id' supabase/config.toml | sed 's/.*"\(.*\)".*/\1/')
    if [ -n "$PROJECT_ID" ]; then
        echo "✅ Project linked: $PROJECT_ID"
    else
        echo "✅ Project linked via SUPABASE_ACCESS_TOKEN"
    fi
else
    echo "✅ Project linked via SUPABASE_ACCESS_TOKEN (CI/CD mode)"
fi
echo ""

# Parse command line arguments
SKIP_MIGRATIONS=false
SKIP_FUNCTIONS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-migrations)
            SKIP_MIGRATIONS=true
            shift
            ;;
        --skip-functions)
            SKIP_FUNCTIONS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./deploy.sh [--skip-migrations] [--skip-functions] [--dry-run]"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN MODE - No changes will be made"
    echo ""
fi

# Deploy database migrations
if [ "$SKIP_MIGRATIONS" = false ]; then
    echo "📊 Deploying Database Migrations..."
    echo "-----------------------------------"
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would run: supabase db push"
    else
        supabase db push
        echo "✅ Database migrations deployed"
    fi
    echo ""
else
    echo "⏭️  Skipping database migrations"
    echo ""
fi

# Deploy Edge Functions
if [ "$SKIP_FUNCTIONS" = false ]; then
    echo "⚡ Deploying Edge Functions..."
    echo "------------------------------"
    
    # List of functions to deploy
    FUNCTIONS=(
        "_shared"
        "auth-profile-setup"
        "oauth-youtube-init"
        "oauth-youtube-callback"
        "oauth-instagram-init"
        "oauth-instagram-callback"
        "oauth-tiktok-init"
        "oauth-tiktok-callback"
        "sync-youtube"
        "sync-instagram"
        "sync-tiktok"
        "ai-generate-tags"
        "search-creators"
        "search-content"
        "get-trending"
        "get-creator-by-slug"
        "track-click"
        "browse-creators"
        "browse-content"
        "get-content-detail"
        "browse-categories"
        "get-seo-metadata"
        "sitemap"
        "robots"
    )
    
    DEPLOYED=0
    FAILED=0
    
    for func in "${FUNCTIONS[@]}"; do
        # Skip _shared as it's not a deployable function
        if [ "$func" = "_shared" ]; then
            continue
        fi
        
        echo "  Deploying $func..."
        
        if [ "$DRY_RUN" = true ]; then
            echo "    Would run: supabase functions deploy $func"
            DEPLOYED=$((DEPLOYED + 1))
        else
            if supabase functions deploy "$func" --no-verify-jwt; then
                echo "    ✅ $func deployed successfully"
                DEPLOYED=$((DEPLOYED + 1))
            else
                echo "    ❌ $func deployment failed"
                FAILED=$((FAILED + 1))
            fi
        fi
    done
    
    echo ""
    echo "Edge Functions Summary:"
    echo "  ✅ Deployed: $DEPLOYED"
    if [ $FAILED -gt 0 ]; then
        echo "  ❌ Failed: $FAILED"
    fi
    echo ""
else
    echo "⏭️  Skipping Edge Functions deployment"
    echo ""
fi

# Set environment secrets (reminder)
echo "🔐 Environment Secrets Reminder"
echo "-------------------------------"
echo "Make sure these secrets are set in Supabase Dashboard → Project Settings → Edge Functions:"
echo ""
echo "  OAuth:"
echo "    - YOUTUBE_CLIENT_ID"
echo "    - YOUTUBE_CLIENT_SECRET"
echo "    - YOUTUBE_REDIRECT_URI"
echo "    - INSTAGRAM_CLIENT_ID"
echo "    - INSTAGRAM_CLIENT_SECRET"
echo "    - INSTAGRAM_REDIRECT_URI"
echo "    - TIKTOK_CLIENT_KEY"
echo "    - TIKTOK_CLIENT_SECRET"
echo "    - TIKTOK_REDIRECT_URI"
echo ""
echo "  AI:"
echo "    - OPENAI_API_KEY"
echo ""
echo "  App:"
echo "    - APP_BASE_URL (e.g., https://streamvibe.com)"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo "✨ Deployment Complete!"
else
    echo "✨ Dry Run Complete!"
fi
echo ""
echo "Next steps:"
echo "  1. Verify Edge Functions: https://supabase.com/dashboard/project/_/functions"
echo "  2. Test with Postman collection"
echo "  3. Monitor logs: supabase functions logs"
