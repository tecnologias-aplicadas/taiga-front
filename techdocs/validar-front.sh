#!/usr/bin/env bash
# Validação do taiga-front com saída curta, para agentes e para gente.
#
#   techdocs/validar-front.sh            lint + Karma headless sobre o dist existente (não reconstrói)
#   techdocs/validar-front.sh --build    idem, mas roda `gulp deploy` antes (derruba o `npm start` que estiver de pé)
#   techdocs/validar-front.sh --lint     só scss-lint
#
# Imprime só: resultado do lint, linha "Executed X of Y", nomes únicos das specs que falharam.
# O log completo fica em tmp/validar-front.log. Exige Node 16 (nvm use 16). Rodar da raiz do taiga-front.

set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p tmp
LOG="tmp/validar-front.log"
: > "$LOG"

MODO="${1:-}"

echo "== scss-lint"
if npm run -s scss-lint >>"$LOG" 2>&1; then
    echo "ok, zero avisos"
else
    echo "FALHOU (ver $LOG)"
    grep -E "^\s+[0-9]+:[0-9]+" "$LOG" | head -20
fi
[ "$MODO" = "--lint" ] && exit 0

if [ "$MODO" = "--build" ]; then
    if pgrep -f "gulp$" >/dev/null 2>&1; then
        echo "== build: há um gulp (npm start) rodando; o deploy vai quebrar o servidor dele. Abortando. Pare o npm start ou rode sem --build."
        exit 2
    fi
    echo "== gulp deploy"
    if npx gulp deploy >>"$LOG" 2>&1; then echo "ok"; else echo "FALHOU (ver $LOG)"; exit 1; fi
fi

if ! ls -d dist/v-* >/dev/null 2>&1; then
    echo "== karma: não há dist/v-*; rode com --build ou suba o npm start antes."
    exit 1
fi

echo "== karma (ChromeHeadlessCI, sobre o dist existente)"
./node_modules/karma/bin/karma start --single-run --browsers=ChromeHeadlessCI >>"$LOG" 2>&1
RC=$?
tr '\r' '\n' < "$LOG" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | grep -E "Executed [0-9]+ of [0-9]+" | tail -1
echo "-- specs que falharam (nomes únicos):"
grep -E "FAILED$" "$LOG" | sed -E 's/.*\) //' | sort -u
echo "-- exit karma: $RC (log completo: $LOG)"
