#!/bin/sh

# ci_post_clone.sh
# Xcode Cloud runs this script after cloning the repository.
# It generates Secrets.xcconfig from environment variables configured in Xcode Cloud.

set -e

echo "Generating Secrets.xcconfig for Xcode Cloud build..."

SECRETS_FILE="$CI_PRIMARY_REPOSITORY_PATH/Secrets.xcconfig"

cat > "$SECRETS_FILE" <<EOF
SLASH = /
SUPABASE_PROJECT_URL = https:\$(SLASH)\$(SLASH)${SUPABASE_PROJECT_URL_HOST}
SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY}
ANALYTICS_API_KEY = ${ANALYTICS_API_KEY}
EOF

echo "Secrets.xcconfig generated successfully."
