#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing

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

### crea RSS ###

# anagrafica RSS
titolo="AlboPOP del comune di Patti"
descrizione="L'albo pretorio POP è una versione dell'albo pretorio del tuo comune, che puoi seguire in modo più comodo."
nomecomune="patti"
webMaster="antonino.galante@gmail.com (Nino Galante)"
type="Comune"
municipality="Patti"
province="Messina"
region="Sicilia"
latitude="38.138226"
longitude="14.966359"
country="Italia"
name="Comune di Patti"
uid="istat:083066"
docs="http://albopop.it/comune/patti/"
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
xmlstarlet ed -L --subnode "//channel" --type elem -n docs -v "$docs" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$type" -i "//channel/category[1]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-type" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$municipality" -i "//channel/category[2]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-municipality" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$province" -i "//channel/category[3]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-province" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$region" -i "//channel/category[4]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-region" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$latitude" -i "//channel/category[5]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-latitude" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$longitude" -i "//channel/category[6]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-longitude" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$country" -i "//channel/category[7]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-country" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$name" -i "//channel/category[8]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-name" "$folder"/processing/feed.xml
xmlstarlet ed -L --subnode "//channel" --type elem -n category -v "$uid" -i "//channel/category[9]" -t "attr" -n "domain" -v "http://albopop.it/specs#channel-category-uid" "$folder"/processing/feed.xml

#17	769	2020-06-15	Riconoscimento della legittimità dei debiti fuori bilancio ai sensi dell&apos;articolo 73, comma 1, lettera a) del decreto legislativo 23 giugno 2011, n. 118 e successive modifiche ed integrazioni. D.F.B. 2020 - mese Febbraio	Mon, 15 Jun 2020 00:00:00 +0000	https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL+E+%28769%29.NUMDDL%29

# leggo in loop i dati del file CSV e li uso per creare nuovi item nel file XML
newcounter=0
while IFS=$'\t' read -r legislatura numero data titolo RSSdate URL; do
  newcounter=$(expr $newcounter + 1)
  xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
    --subnode "//item[$newcounter]" --type elem -n title -v "$titolo" \
    --subnode "//item[$newcounter]" --type elem -n description -v "$titolo" \
    --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
    --subnode "//item[$newcounter]" --type elem -n pubDate -v "$RSSdate" \
    --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
    "$folder"/processing/feed.xml
done <"$folder"/rawdata/rss.tsv

#sed -i -r 's/(http.+?)(\&amp;)(.+)$/\1\&\3/g' "$folder"/processing/feed.xml

<<commento
commento
