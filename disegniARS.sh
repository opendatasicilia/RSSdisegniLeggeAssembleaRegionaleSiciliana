#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/rawdata

URLquerybase="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL%29"

curl -kL -c "$folder"/rawdata/cookie "$URLquerybase"

curl -kL -b "$folder"/rawdata/cookie "https://w3.ars.sicilia.it/icaro/shortList.jsp?_=" >"$folder"/rawdata/risultati.html
