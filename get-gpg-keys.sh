#!/bin/bash
set -euo pipefail

echo "Enter your GitHub username"
read -r github_username
echo "Enter your GitHub Access Token (read:org scope required)"
read -r github_token
echo "Enter the GitHub organisation slug (as it appears in URLs)"
read -r github_org

github_request () {
  curl -su "$github_username:$github_token" "https://api.github.com/$1"
}

members=$(github_request "orgs/$github_org/members?per_page=100")
users=$(echo "$members" | jq -r '.[].login')

for user in $users; do
  user_key_response=$(github_request "users/$user/gpg_keys")
  raw_key="$(echo "$user_key_response" | jq -r '.[0].raw_key')"

  if [[ "$raw_key" != "null" ]]; then
    # I don't know. GitHub gives annoying \r\n stuff and it's annoying.
    # Did I mention it's annoying? It's annoying.
    echo "$user_key_response" | jq -r '.[0].raw_key' > "keys/$user.pub"
    gpg --import "keys/$user.pub"
  fi
done
