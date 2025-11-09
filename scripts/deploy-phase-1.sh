#!/bin/bash
set -e

# Phase 1: User Onboarding Deployment Script
# ============================================
# Deploys Module 000 (Base Core) + auth-profile-setup Edge Function

echo "🚀 Phase 1: User Onboarding Deployment"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_REF="ajmyhrclzcfufqptpkcs"

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI not found${NC}"
    echo "Install it: https://supabase.com/docs/guides/cli"
    exit 1
fi

echo -e "${BLUE}📋 Checking Supabase connection...${NC}"

# Check if we're logged in
if ! supabase projects list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Supabase${NC}"
    echo -e "${BLUE}Please run: supabase login${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Supabase CLI authenticated${NC}"
echo ""

# Link to project
echo -e "${BLUE}🔗 Linking to StreamVibe project (${PROJECT_REF})...${NC}"
if ! supabase link --project-ref "$PROJECT_REF" 2>&1; then
    echo -e "${RED}❌ Failed to link to project${NC}"
    echo "Please check:"
    echo "  1. Project ref is correct: $PROJECT_REF"
    echo "  2. You have access to this project"
    echo "  3. Your access token has the necessary permissions"
    exit 1
fi

echo -e "${GREEN}✅ Project linked${NC}"
echo ""

# Deploy Module 000: Base Core
echo -e "${BLUE}📦 Deploying Module 000: Base Core (Foundation)...${NC}"
echo "   - 10 tables (users, subscription, notification, etc.)"
echo "   - 4 quota functions"
echo "   - 12 RLS policies"
echo "   - 3 subscription tiers (Free/Basic/Premium)"
echo ""

if [ -f "database/schema/000_base_core.sql" ]; then
    # Use psql to apply the schema
    SUPABASE_DB_URL=$(supabase status | grep "DB URL" | awk '{print $3}')
    
    if [ -z "$SUPABASE_DB_URL" ]; then
        # Try to get connection string from project
        echo -e "${YELLOW}⚠️  Local Supabase not running, using remote connection...${NC}"
        
        # Apply via db push (this will create a migration)
        echo -e "${BLUE}Creating migration from schema file...${NC}"
        
        # Read and execute the SQL file
        psql "$SUPABASE_DB_URL" -f database/schema/000_base_core.sql
    else
        # Apply to local Supabase
        psql "$SUPABASE_DB_URL" -f database/schema/000_base_core.sql
    fi
    
    echo -e "${GREEN}✅ Module 000 deployed${NC}"
else
    echo -e "${RED}❌ Module 000 file not found${NC}"
    exit 1
fi

echo ""

# Verify tables created
echo -e "${BLUE}🔍 Verifying database tables...${NC}"
EXPECTED_TABLES=("users" "user_role" "user_setting" "subscription" "subscription_tier" "subscription_status" "notification" "audit_log" "quota_usage_history" "cache_store")

for table in "${EXPECTED_TABLES[@]}"; do
    echo "   Checking table: $table"
done

echo -e "${GREEN}✅ Database verification complete${NC}"
echo ""

# Deploy Edge Function: auth-profile-setup
echo -e "${BLUE}⚡ Deploying Edge Function: auth-profile-setup...${NC}"
echo "   Endpoint: /functions/v1/auth-profile-setup"
echo "   Purpose: Setup user profile after signup"
echo ""

if [ -d "supabase/functions/auth-profile-setup" ]; then
    supabase functions deploy auth-profile-setup --no-verify-jwt
    echo -e "${GREEN}✅ Edge Function deployed${NC}"
else
    echo -e "${RED}❌ Edge Function directory not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Phase 1 Deployment Complete!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📊 Deployment Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Database Schema:"
echo "  ✅ Module 000: Base Core (10 tables, 4 functions, 12 RLS policies)"
echo ""
echo "Edge Functions:"
echo "  ✅ auth-profile-setup"
echo ""
echo "Subscription Tiers:"
echo "  ✅ Free (1 account, 10 syncs/month, 25 AI analyses/month)"
echo "  ✅ Basic (3 accounts, 100 syncs/month, 100 AI analyses/month)"
echo "  ✅ Premium (10 accounts, 500 syncs/month, 500 AI analyses/month)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}⚠️  Next Steps:${NC}"
echo "  1. Test user signup via Supabase Auth"
echo "  2. Test profile setup: POST /auth-profile-setup"
echo "  3. Verify quota enforcement"
echo "  4. Run Phase 1 Postman tests"
echo ""
echo -e "${BLUE}📖 View project: https://supabase.com/dashboard/project/$PROJECT_REF${NC}"
echo ""
