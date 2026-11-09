# documenso (Fairhomes' fork)

Upstreams regler står i `AGENTS.md`. Svar til Junaid på dansk.

## Godkendt PRD (Junaid 9/11-2026, PRD «Autonome sessioner»)
En godkendt PRD er godkendelse af alle dens skridt. Regler i denne fil om «Junaids ja i samme samtale» gælder kun uden
for en godkendt PRD.
- **Godkendt:** Junaid har sagt ja til PRD'en i samtalen (fx «implementer» eller «go»), og sessionen har skrevet dens
  kontrakt i `.claude/prd-kontrakt.json` (mål, handlinger, udløb; skabelon i
  `fairhomes-infra/claude/prd-kontrakt.eksempel.json`). Skrivningen af kontrakten giver én dialog, hvor Junaid ser mål
  og handlinger: det er PRD-ja'et. `.claude/hooks/prd-vagt.sh` slipper skridt i kontrakten igennem, afviser mål og
  handlinger uden for den og logger hvert kald mod PROD med PRD-id og commit (`prd-vagt.sh --rapport` i PR'en).
- **Godkendt PRD = godkendte skridt:** SQL, deploys, servertilstand, Digital Post-undtagelser, PONR og nøgler er ikke
  faste stop, når skridtet eller dets skabelon står i PRD'en. Sessionen spørger ikke igen og kører til ende.
- **Undtagelse: udgående mail** til mennesker kræver stadig Junaids ja i samtalen; `.claude/hooks/mail-vagt.sh` beder
  om det. Kladder er tilladt.
- **Merge:** sessionen merger selv efter grøn CI og AI-review, når PR'en hører til PRD'en (`merge` i kontraktens
  handlinger og repoet i dens mål).
- **Bevares:** AI-review før merge og `opus`-review af skrivende SQL før kørsel (automatisk, ingen klik), append-only,
  ingen `disable trigger` eller `session_replication_role`, nøgler aldrig i repo, chat eller log, og én ting ad gangen
  mod PROD (agentens egen rækkefølge, ikke klik).
- **Opsætning frem for dialoger:** tokens og CLI i miljøet, wrappers på serveren og faste allow-regler i
  `.claude/settings.json` frem for MCP-dialoger. Platformens egne dialoger (miljøændringer, nye credentials, Supabase
  Cloud) kan ikke slås fra og bruges kun ved opsætningen.
- **Uden for PRD'en:** et skridt, der ikke står i den, kræver Junaids ja som før; saml spørgsmålene i ét.
