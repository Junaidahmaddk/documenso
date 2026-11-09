#!/usr/bin/env bash
# mail-vagt.sh: PreToolUse-hook, der stopper udgående mail til mennesker og beder om Junaids ja («ask»), også under en
# godkendt PRD (PRD «Autonome sessioner», beslutning 2, Junaid 6/11-2026). Kladder er tilladt.
#
# Kilde: fairhomes-infra/claude/hooks/mail-vagt.sh. Kopieres uændret til <repo>/.claude/hooks/ med
# fairhomes-infra/claude/synk.sh; ret kun kilden.
#
# Fanger:
#   - MCP-værktøjer, der sender, svarer eller videresender: Gmail (alle servernavne), Outlook/Microsoft, Kit-broadcasts,
#     SMTP-/mailtjenester, og FH Signerings send_document/send_reminder (de mailer underskriverne).
#   - Composio-slugs som GMAIL_SEND_EMAIL, GMAIL_REPLY_TO_THREAD, GMAIL_FORWARD_MESSAGE, GMAIL_SEND_DRAFT, OUTLOOK_SEND_*.
#   - Kommandoer (Bash, desktop-commanders terminal, Composios fjern-bash) med sendmail, msmtp, mutt, mailx, mail -s,
#     swaks, smtp(s)://, --mail-rcpt, smtplib og digitalpost-alarm --test-mail.
# Ikke: kladder (create_draft, update_draft, GMAIL_CREATE_EMAIL_DRAFT), læsning og etiketter.
# Repoer, hvor systemet aldrig sender (fairhomes-triage), afviser desuden værktøjerne i .claude/settings.json; deny vinder.
# Fanger fejltrin, ikke en modstander. `mail-vagt.sh --selvtest` kører de indbyggede tilfælde.
set -uo pipefail
export LC_ALL=C

GRUND="Udgående mail til mennesker kræver Junaids ja i samtalen, også under en godkendt PRD (beslutning 2). Kladder er tilladt."

svar_ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$GRUND"
}

# 0 = kaldet sender mail. Input: værktøjsnavn og hele input-JSON som tekst.
sender_mail() {
  local navn="$1" raa="$2" lt srv kort
  lt="${raa,,}"
  case "$navn" in
    mcp__*)
      srv="${navn#mcp__}"; srv="${srv%%__*}"; srv="${srv,,}"; kort="${navn##*__}"; kort="${kort,,}"
      case "$kort" in *draft*) [[ "$kort" == *send* ]] || return 1 ;; esac
      if [[ "$srv" =~ (gmail|outlook|microsoft|smtp|sendgrid|mailgun|resend|postmark|mailchimp) ]] && [[ "$kort" =~ (send|reply|forward) ]]; then return 0; fi
      if [[ "$srv" =~ (^|_)kit($|_) ]] && [[ "$kort" =~ (send|broadcast) ]] && ! [[ "$kort" =~ ^(get|list) ]]; then return 0; fi
      if [[ "$srv" =~ signering ]] && [[ "$kort" =~ ^(send_document|send_reminder)$ ]]; then return 0; fi
      if [[ "$srv" =~ composio ]] && [[ "$lt" =~ (gmail\.googleapis\.com|graph\.microsoft\.com|api\.resend\.com|api\.sendgrid\.com|api\.mailgun\.net) ]]; then
        [[ "$lt" =~ (/send|sendmail|/reply|/forward|/emails|/messages) ]] && return 0
      fi
      if [[ "$srv" =~ composio ]]; then
        grep -qE '"?(gmail|outlook|microsoft_outlook|sendgrid|mailgun|resend|postmark)_[a-z0-9_]*(send|reply|forward)[a-z0-9_]*"?' <<< "$lt" && return 0
      fi ;;
  esac
  # Kommandotekst (Bash, desktop-commander start_process/interact_with_process, Composios fjern-bash).
  case "$navn" in
    Bash | mcp__*[Dd]esktop*[Cc]ommander__start_process | mcp__*[Dd]esktop*[Cc]ommander__interact_with_process | mcp__*[Cc]omposio*) ;;
    *) return 1 ;;
  esac
  # En enkelt søge- eller tekstkommando uden kæde (grep sendmail, git commit -m "… smtp …") sender intet.
  local cmd
  cmd="$(jq -r '.command // .input // empty' <<< "$raa" 2>/dev/null)"
  if [[ -n "$cmd" && "$cmd" != *[\;\&\|\`\<\>]* && "$cmd" != *\$\(* && "$cmd" != *$'\n'* ]] \
     && [[ "$cmd" =~ ^[[:space:]]*(grep|egrep|rg|cat|less|head|tail|ls|wc|git[[:space:]]+(log|show|diff|grep|status|commit|add)|gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|view))([[:space:]]|$) ]]; then
    return 1
  fi
  [[ "$lt" =~ (^|[^a-z0-9_-])(sendmail|msmtp|mutt|mailx|swaks|ssmtp)([^a-z0-9_-]|$) ]] && return 0
  [[ "$lt" =~ (^|[^a-z0-9_-])mail[[:space:]]+(-[a-z]+[[:space:]]+)*-s[[:space:]] ]] && return 0
  [[ "$lt" =~ smtps?:// || "$lt" =~ --mail-rcpt || "$lt" =~ smtplib || "$lt" =~ digitalpost-alarm.*--test-mail ]] && return 0
  # Mail-API'er (også via Composios proxy).
  [[ "$lt" =~ (api\.resend\.com|api\.sendgrid\.com|api\.mailgun\.net|api\.postmarkapp\.com|gmail\.googleapis\.com/[^[:space:]\"]*/(send|messages/send|drafts/send)|graph\.microsoft\.com/[^[:space:]\"]*/(sendmail|send|reply|forward)) ]] && return 0
  # Kørsler, der selv mailer: Digital Posts poller, videresendelse og alarm uden --vis/--toer-koersel, og triagens
  # digest, alarm og videresendelse (også i compose run på serveren).
  # Undtagelsen (--vis, --toer-koersel) gælder kun en enkelt kommando uden kæde, og kun de præcise flag.
  local en=0
  [[ -n "$cmd" && "$cmd" != *[\;\&\|\`\<\>]* && "$cmd" != *\$\(* && "$cmd" != *$'\n'* ]] && en=1
  if [[ "$lt" =~ digitalpost-(poll|videresend|alarm)|digitalpost\.(poller|videresend|alarm) ]]; then
    (( en )) && [[ " ${cmd,,} " =~ [[:space:]]--(vis|toer-koersel)[[:space:]] ]] || return 0
  fi
  if [[ "$lt" =~ triage-(digest|alarm|videresend|poll)|triage\.(digest|alarm|videresend|poller) ]]; then
    (( en )) && [[ " ${cmd,,} " =~ [[:space:]]--vis[[:space:]] ]] || return 0
  fi
  return 1
}

vurder() {
  local in navn raa
  in="$(cat)"
  if command -v jq >/dev/null 2>&1; then
    navn="$(jq -r '.tool_name // ""' <<< "$in" 2>/dev/null)"
    raa="$(jq -c '.tool_input // {}' <<< "$in" 2>/dev/null)"
  else
    # Uden jq: navnet med sed, og hele inputtet som tekst. Vagten fejler hellere for meget end for lidt.
    navn="$(sed -nE 's/.*"tool_name" *: *"([^"]*)".*/\1/p' <<< "$in" | head -1)"
    raa="$in"
  fi
  if sender_mail "$navn" "$raa"; then svar_ask; fi
  return 0
}

selvtest() {
  local fejl=0 n=0
  t() { # forventet(ask|-) navn input-json
    local ud fik
    ud="$(printf '{"tool_name":"%s","tool_input":%s}' "$2" "$3" | vurder)"
    [[ "$ud" == *'"ask"'* ]] && fik=ask || fik=-
    n=$((n + 1))
    if [[ "$fik" == "$1" ]]; then echo "  ok   $1  $2 $3"; else echo "  FEJL forventede $1, fik $fik: $2 $3"; fejl=$((fejl + 1)); fi
  }
  t ask mcp__Gmail__send_message '{"to":"a@b.dk"}'
  t ask mcp__Gmail__reply '{"messageId":"x"}'
  t ask mcp__Gmail__forward '{"messageId":"x","to":"a@b.dk"}'
  t ask mcp__plugin_engineering_gmail__send_email '{"to":"a@b.dk"}'
  t ask mcp__Fairhomes_Signering__send_document '{"id":1}'
  t ask mcp__Fairhomes_Signering__send_reminder '{"id":1}'
  t ask mcp__Kit__send_broadcast '{"id":1}'
  t ask mcp__Composio__COMPOSIO_MULTI_EXECUTE_TOOL '{"tools":[{"tool_slug":"GMAIL_SEND_EMAIL","arguments":{}}]}'
  t ask mcp__Composio__COMPOSIO_MULTI_EXECUTE_TOOL '{"tools":[{"tool_slug":"GMAIL_REPLY_TO_THREAD"}]}'
  t ask Bash '{"command":"echo hej | mail -s Emne a@b.dk"}'
  t ask Bash '{"command":"curl --url smtps://smtp.gmail.com:465 --mail-rcpt a@b.dk -T x.eml"}'
  t ask Bash '{"command":"python3 -c \"import smtplib\""}'
  t ask Bash '{"command":"uv run digitalpost-alarm --test-mail"}'
  t ask mcp__Remote_Desktop_Commander__start_process '{"command":"sendmail a@b.dk < x"}'
  t - mcp__Gmail__create_draft '{"to":"a@b.dk"}'
  t - mcp__Gmail__update_draft '{"to":"a@b.dk"}'
  t - mcp__Gmail__search_threads '{"query":"send"}'
  t - mcp__Gmail__label_message '{"id":"x"}'
  t - mcp__Composio__COMPOSIO_MULTI_EXECUTE_TOOL '{"tools":[{"tool_slug":"GMAIL_CREATE_EMAIL_DRAFT"}]}'
  t - mcp__Kit__list_broadcasts '{}'
  t - Bash '{"command":"grep -rn sendmail docs/"}'
  t ask Bash '{"command":"grep x y; sendmail a@b.dk < z"}'
  t - Bash '{"command":"git commit -m \"smtp: ret smtps://-adressen\""}'
  t - Bash '{"command":"uv run digitalpost-alarm --vis"}'
  t ask Bash '{"command":"curl -X POST https://api.resend.com/emails -d @m.json"}'
  t ask Bash '{"command":"curl -X POST https://gmail.googleapis.com/gmail/v1/users/me/messages/send -d @m.json"}'
  t ask mcp__Composio__COMPOSIO_PROXY_EXECUTE '{"endpoint":"https://gmail.googleapis.com/gmail/v1/users/me/messages/send","method":"POST"}'
  t ask Bash '{"command":"uv run digitalpost-videresend"}'
  t ask Bash '{"command":"uv run digitalpost-alarm --ugerapport"}'
  t - Bash '{"command":"uv run digitalpost-alarm --ugerapport --vis"}'
  t - Bash '{"command":"uv run digitalpost-poll --cvr 46449983 --toer-koersel"}'
  t ask Bash '{"command":"ssh claude@fhdk1 sudo fh-compose triage run worker triage-digest"}'
  t ask Bash '{"command":"cat <(sendmail a@b.dk < x)"}'
  t - Bash '{"command":"grep -rn triage-digest docs/"}'
  t ask Bash '{"command":"uv run digitalpost-alarm --ugerapport --vis; uv run digitalpost-alarm --ugerapport"}'
  t ask Bash '{"command":"uv run digitalpost-alarm --test-mail"}'
  t ask Bash '{"command":"uv run digitalpost-poll --toer-koersel=false"}'
  t ask Bash '{"command":"python -m digitalpost.poller"}'
  t ask Bash '{"command":"python -m triage.digest"}'
  t ask Bash '{"command":"uv run triage-poll"}'
  t - Bash '{"command":"uv run triage-digest --vis"}'
  t - mcp__Fairhomes_Signering__list_submissions '{}'
  t - Write '{"file_path":"x.md","content":"sendmail"}'
  echo "-- $n tjek, $fejl fejl"
  (( fejl == 0 ))
}

case "${1:-}" in
  --selvtest) selvtest; exit $? ;;
  *) vurder; exit 0 ;;
esac
