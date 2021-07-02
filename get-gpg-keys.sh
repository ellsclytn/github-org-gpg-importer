#!/bin/bash
set -euo pipefail

github_token_path=access-token.key
github_username_path=username.txt

# https://gist.github.com/davejamesmiller/1965569
ask() {
  local prompt default reply

  if [[ ${2:-} = 'Y' ]]; then
    prompt='Y/n'
    default='Y'
  elif [[ ${2:-} = 'N' ]]; then
    prompt='y/N'
    default='N'
  else
    prompt='y/n'
    default=''
  fi

  while true; do
    # Ask the question (not using "read -p" as it uses stderr not stdout)
    echo -n "$1 [$prompt] "

    # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
    read -r reply </dev/tty

    # Default?
    if [[ -z $reply ]]; then
      reply=$default
    fi

    # Check if the reply is valid
    case "$reply" in
      Y*|y*) return 0 ;;
      N*|n*) return 1 ;;
    esac
  done
}

if [[ -f "$github_username_path" ]]; then
  github_username="$(cat "$github_username_path")"
else
  echo "Enter your GitHub username"
  read -r github_username

  if ask "Do you want this username saved for future use?" Y; then
    echo "$github_username" > "$github_username_path"
  fi
fi

if [[ -f "$github_token_path" ]]; then
  github_token="$(cat "$github_token_path")"
else
  echo "Enter your GitHub Access Token (read:org scope required)"
  read -r github_token

  if ask "Do you want this token saved for future use?" Y; then
    echo "$github_token" > "$github_token_path"
  fi
fi

echo "Enter the GitHub organisation slug (as it appears in URLs)"
read -r github_org

github_request () {
  curl -su "$github_username:$github_token" "https://api.github.com/$1"
}

members=$(github_request "orgs/$github_org/members?per_page=100")
users=$(echo "$members" | jq -r '.[].login')

mkdir -p "keys"

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
