#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/doc

rm "$folder"/rawdata/*

### scarica dati di base ###

URLqueryBase="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL%29"

# fai la query di base e imposta cookie
curl -skL -c "$folder"/rawdata/cookie "$URLqueryBase" >/dev/null

URLrisultatiBase="https://w3.ars.sicilia.it/icaro/shortList.jsp?_="

# leggi cooki e ricevi lista risultati
curl -skL -b "$folder"/rawdata/cookie "$URLrisultatiBase" >"$folder"/rawdata/risultati.html

# estrai la lista dei risultati in formato JSON
scrape <"$folder"/rawdata/risultati.html -be '//ul[@id="shortListTable"]/li[position() > 1]' | xq . >"$folder"/rawdata/risultati.json

# estrai i valori dei 4 campi
jq <"$folder"/rawdata/risultati.json -r '.html.body.li[]|{legislatura:.div[0].p.strong["#text"],numero:.div[1].p.strong["#text"],data:.div[2].p.strong["#text"],titolo:.div[4].h3.a["#text"]}' | mlr --j2c unsparsify >"$folder"/rawdata/lista.csv

# normalizza data a aggiungi data RSS
mlr -I --csv clean-whitespace then put '$data=sub($data,"^([^\.]+)(\.)([^\.]+)(\.)([^\.]+)$","20\5-\3-\1")' then put '$RSSdate = strftime(strptime($data, "%Y-%m-%d"),"%a, %d %b %Y %H:%M:%S %z")' "$folder"/rawdata/lista.csv

mlr -I --csv head then put '$URL="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%28".$legislatura.".LEGISL+E+%28".$numero."%29.NUMDDL%29"' "$folder"/rawdata/lista.csv

mlr -I --csv uniq -a "$folder"/rawdata/lista.csv

### crea RSS ###

# anagrafica RSS
titolo="Disegni di legge dell'Assemblea Regionale Siciliana"
descrizione="Un RSS per essere aggiornato sui disegni di legge dell'Assemblea Regionale Siciliana"
webMaster="info@opendatasicilia.it (Open Data Sicilia)"
selflink="http://dev.ondata.it/projs/albopop/patti/feed.xml"

mlr --c2t --quote-none sort -r data \
  then put '$titolo=gsub($titolo,"<","&lt")' \
  then put '$titolo=gsub($titolo,">","&gt;")' \
  then put '$titolo=gsub($titolo,"&","&amp;")' \
  then put '$URL=gsub($URL,"&","&amp;")' \
  then put '$titolo=gsub($titolo,"'\''","&apos;")' \
  then put '$titolo=gsub($titolo,"\"","&quot;")' "$folder"/rawdata/lista.csv |
  tail -n +2 >"$folder"/rawdata/rss.tsv

dos2unix "$folder"/rawdata/rss.tsv

creo una copia del template del feed
cp "$folder"/risorse/feedTemplate.xml "$folder"/processing/feed.xml

# inserisco gli attributi di base nel feed
xmlstarlet ed -L --subnode "//channel" --type elem -n title -v "$titolo" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n description -v "$descrizione" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n link -v "$selflink" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n "atom:link" -v "" -i "//*[name()='atom:link']" -t "attr" -n "rel" -v "self" -i "//*[name()='atom:link']" -t "attr" -n "href" -v "$selflink" -i "//*[name()='atom:link']" -t "attr" -n "type" -v "application/rss+xml" "$folder"/processing/feed.xml

# leggo in loop i dati del file CSV e li uso per creare nuovi item nel file XML
newcounter=0
while IFS=$'\t' read -r legislatura numero data titolo RSSdate URL; do
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "Disegno $numero" \
    --subnode "//item[$newcounter]" --type elem -n description -v "$titolo" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$RSSdate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
    "$folder"/processing/feed.xml
done <"$folder"/rawdata/rss.tsv

cp "$folder"/doc/feed.xml
