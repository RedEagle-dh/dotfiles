ghtest() {
  local pat="$1"
  if [[ -z "$pat" ]]; then
    echo "Usage: ghtest <PAT>  oder  ghtest <PAT> <org>"
    return 1
  fi

  echo "== User =="
  curl -s -H "Authorization: Bearer $pat" \
       -H "Accept: application/vnd.github+json" \
       https://api.github.com/user | command grep -E '"login"|"message"'

  echo "== Scopes =="
  curl -s -I -H "Authorization: Bearer $pat" \
       https://api.github.com/user | command grep -i '^x-oauth-scopes:'

  echo "== Rate Limit =="
  curl -s -H "Authorization: Bearer $pat" \
       https://api.github.com/rate_limit | command grep -E '"limit"|"remaining"' | head -2

  if [[ -n "$2" ]]; then
    local org="$2"
    echo "== Org: $org =="
    curl -s -o /dev/null -w "GET /orgs/$org -> %{http_code}\n" \
         -H "Authorization: Bearer $pat" \
         https://api.github.com/orgs/$org
    curl -s -H "Authorization: Bearer $pat" \
         https://api.github.com/user/memberships/orgs/$org \
         | command grep -E '"state"|"role"|"message"'
  fi
}
