#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing

URLqueryBase="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL%29"

curl -skL -c "$folder"/rawdata/cookie "$URLqueryBase" >/dev/null

URLrisultatiBase="https://w3.ars.sicilia.it/icaro/shortList.jsp?_="

curl -skL -b "$folder"/rawdata/cookie "$URLrisultatiBase" >"$folder"/rawdata/risultati.html

<"$folder"/rawdata/risultati.html scrape -be '//ul[@id="shortListTable"]/li[position() > 1]' | xq . >"$folder"/rawdata/risultati.json

<"$folder"/rawdata/risultati.json jq -r '.html.body.li[].div[0].p.strong["#text"]|{legislatura:.}' | mlr --ijson cat >"$folder"/rawdata/01.txt
<"$folder"/rawdata/risultati.json jq -r '.html.body.li[].div[1].p.strong["#text"]|{numero:.}' | mlr --ijson cat >"$folder"/rawdata/02.txt
<"$folder"/rawdata/risultati.json jq -r '.html.body.li[].div[2].p.strong["#text"]|{data:.}' | mlr --ijson cat >"$folder"/rawdata/03.txt
<"$folder"/rawdata/risultati.json jq -r '.html.body.li[].div[4].h3.a["#text"]|{titolo:.}' | mlr --ijson cat >"$folder"/rawdata/04.txt

paste -d "\t" rawdata/*.txt | mlr --ifs "\t" --ocsv cat  >"$folder"/rawdata/lista.csv
