#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing

rm "$folder"/rawdata/*

URLqueryBase="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL%29"

# fai la query di base e imposta cookie
curl -skL -c "$folder"/rawdata/cookie "$URLqueryBase" >/dev/null

URLrisultatiBase="https://w3.ars.sicilia.it/icaro/shortList.jsp?_="

# leggi cooki e ricevi lista risultati
curl -skL -b "$folder"/rawdata/cookie "$URLrisultatiBase" >"$folder"/rawdata/risultati.html

# estrai la lista dei risultati in formato JSON
<"$folder"/rawdata/risultati.html scrape -be '//ul[@id="shortListTable"]/li[position() > 1]' | xq . >"$folder"/rawdata/risultati.json

# estrai i valori dei 4 campi
<"$folder"/rawdata/risultati.json jq -r '.html.body.li[]|{legislatura:.div[0].p.strong["#text"],numero:.div[1].p.strong["#text"],data:.div[2].p.strong["#text"],titolo:.div[4].h3.a["#text"]}' | mlr --j2c unsparsify >"$folder"/rawdata/lista.csv
