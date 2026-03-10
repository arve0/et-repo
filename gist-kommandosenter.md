# gist-kommandosenter
Et bash-script som lar en kjøre kommandoer remote via en Github gist.

## Plan
Start med en funksjon `main` som inneholder funksjonene gitt av stegene under. Eksempelvis:

```shell
#!/usr/bin/env bash
set -eo pipefail

main() {
  init
  while true; do
    if har_nye_kommentarer; then
    fi
  done
}

# functions here

main "$@"
```

### 1. Oppstart og initialisering
Funksjonsnavn: `init`
- Sjekk at `gh` (GitHub CLI) er installert og autentisert (`gh auth status`), avslutt med feilmelding hvis ikke.
- Hent innlogget brukernamn med `gh api user --jq .login` og lagre det som `OWNER`.
- Opprett en tom, offentlig gist med en plassholderfil (f.eks. `kommandosenter.md`) og en beskrivende `--desc`:
  ```
  GIST_URL=$(gh gist create --public --desc "kommandosenter" kommandosenter.md)
  GIST_ID=$(basename "$GIST_URL")
  ```
- Skriv ut gist-URL-en til terminalen så brukeren vet hvor de skal sende kommandoer.

### 2. Polling-løkke
Funksjonsnavn: `har_nye_kommentarer`
- Kjør en uendelig `while true`-løkke med et konfigurerbart intervall (f.eks. `POLL_INTERVAL=60` sekunder).
- Hold styr på siste behandlede kommentar-ID i en variabel (`LAST_COMMENT_ID=0`) for å unngå å kjøre samme kommando to ganger.

### 3. Henting og filtrering av kommentarer
Funksjonsnavn: `hent_neste_kommentar`
- Hent alle kommentarer på gisten via GitHub-APIet:
  ```
  gh api repos/gists/$GIST_ID/comments --jq '.[] | {id:.id, user:.user.login, body:.body}'
  ```
- Iterer over kommentarene og behandle bare de med `id > LAST_COMMENT_ID`.
- Filtrer på at `user == OWNER` (bare eierens kommentarer utløser kjøring).
- Sjekk om kommentarteksten matcher mønsteret `run: <kommando>` (case-insensitiv trim).

### 4. Kommandokjøring
Funksjonsnav: `prosseser_kommentar`
- Ekstraher kommandoteksten etter `run: `.
- Kjør kommandoen i en subshell og fang både stdout og stderr:
  ```bash
  OUTPUT=$(eval "$CMD" 2>&1)
  EXIT_CODE=$?
  ```
- Begrens output-lengde (f.eks. maks 60 000 tegn) for å unngå å overskride GitHub API-grensen for kommentarstørrelse.

### 5. Tilbakeskriving av resultat
Funksjonsnavn: `post_resultat`
- Post resultatet som en ny kommentar på gisten:
  ```
  gh api repos/gists/$GIST_ID/comments -f body="$(printf '**$ %s**\n```\n%s\n```\nExit code: %d' "$CMD" "$OUTPUT" "$EXIT_CODE")"
  ```
- Oppdater `LAST_COMMENT_ID` til ID-en på den sist behandlede kommentaren.

### 6. Avslutning
- Fang `SIGINT`/`SIGTERM` med `trap` for ryddig avslutning.
- Ved avslutning: post en siste kommentar om at kommandosenteret er avsluttet.

### 7. Konfigurasjon (miljøvariabler)
| Variabel | Standard | Beskrivelse |
|---|---|---|
| `POLL_INTERVAL` | `60` | Sekunder mellom hver polling |
| `MAX_OUTPUT` | `60000` | Maks antall tegn i output-kommentar |
