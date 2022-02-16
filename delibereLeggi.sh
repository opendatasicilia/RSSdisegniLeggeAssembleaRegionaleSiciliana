#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URLbase="https://www2.regione.sicilia.it/deliberegiunta/index.asp"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing

# leggi la risposta HTTP del sito
code=$(curl -s -L -o /dev/null -w "%{http_code}" ''"$URLbase"'')

# se il sito è raggiungibile scarica i dati
if [ $code -eq 200 ]; then

  anno=$(date +"%Y")

  # imposta cookie
  curl -c "$folder"/rawdata/cookie 'https://www2.regione.sicilia.it/deliberegiunta/index.asp' >/dev/null

  # scarica HTML dell'anno
  curl -b "$folder"/rawdata/cookie -kL 'https://www2.regione.sicilia.it/deliberegiunta/RicercaDelibereN.asp' \
  -H 'Connection: keep-alive' \
  -H 'Cache-Control: max-age=0' \
  -H 'sec-ch-ua: " Not A;Brand";v="99", "Chromium";v="98", "Google Chrome";v="98"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Windows"' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Origin: https://www2.regione.sicilia.it' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Referer: https://www2.regione.sicilia.it/deliberegiunta/index.asp' \
  -H 'Accept-Language: en-US,en;q=0.9,it;q=0.8' \
  --data-raw 'anno='"$anno"'&assessorato=---&numero=&optTipoDel=&txtDescrizione=&optTipoRic=0&cmdbtn=Visualizza' \
  --compressed >"$folder"/rawdata/"$anno"_delibereLeggi.html

  # estrai dall'HTML la tabella e convertila in JSON
  scrape <"$folder"/rawdata/"$anno"_delibereLeggi.html -be '//table/tr[position() < last() and position()>1]' | xq '.html.body.tr' >"$folder"/rawdata/"$anno"_delibereLeggi.json

  # estrai dal JSON i soli dati che servono e trasformali in CSV
  jq <"$folder"/rawdata/"$anno"_delibereLeggi.json '.[]|{numero:.td[0]["#text"],data:.td[1]["#text"],descrizione:.td[2]["#text"],assessorato:.td[3]?["#text"]?,nomine:.td[4].b?,spesa:.td[5].b?,ddl:.td[6]?["#text"]?,file:.td[7].a[0]?["@href"]?}' | mlr --j2c unsparsify then put '$anno='"$anno"'' >"$folder"/rawdata/"$anno".csv

  # fai pulizia spazi bianchi e aggiuni URL file
  mlr --csv clean-whitespace then put '$file=sub($file,"\./file/","https://www2.regione.sicilia.it/deliberegiunta/file/");$file=gsub($file," ","%20")' "$folder"/rawdata/"$anno".csv >"$folder"/processing/delibereLeggi.csv

  # ordina per anno e numero
  mlr -I --csv sort -nr anno,numero "$folder"/processing/delibereLeggi.csv

  # rimuovi dalle date il "." e sostituisci con "/"
  mlr -I --csv put '$data=gsub($data,"\.","/")' "$folder"/processing/delibereLeggi.csv

  # aggiungi campo con formato data RSS
  mlr -I --csv put 'if ($data =~ "[0-9]+/[0-9]+/[0-9]{4}") {$RSSdate = strftime(strptime($data, "%d/%m/%Y"),"%a, %d %b %Y %H:%M:%S %z")} else {$RSSdate = ""}' "$folder"/processing/delibereLeggi.csv

  # aggiungi campo con formato data YYYY-MM-DD
  mlr -I --csv put 'if ($data =~ "[0-9]+/[0-9]+/[0-9]{4}") {$datetime = strftime(strptime($data, "%d/%m/%Y"),"%Y-%m-%d")} else {$datetime = ""}' "$folder"/processing/delibereLeggi.csv

  ### crea RSS ###

  # anagrafica RSS
  titolo="Regione Siciliana | Delibere e Disegni di Legge del Governo"
  descrizione="Per essere aggiornato su Delibere e Disegni di Legge approvate dal parlamento regionale siciliano"
  webMaster="info@opendatasicilia.it (Open Data Sicilia)"
  selflink="https://opendatasicilia.github.io/RSSdisegniLeggeAssembleaRegionaleSiciliana/delibereLeggi_feed.xml"

  # crea file TSV sorgente dati RSS e fai pulizia caratteri
  mlr -I --csv put '$descrizione=gsub($descrizione,"<","&lt")' \
    then put '$descrizione=gsub($descrizione,">","&gt;")' \
    then put '$descrizione=gsub($descrizione,"&","&amp;")' \
    then put '$file=gsub($file,"&","&amp;")' \
    then put '$descrizione=gsub($descrizione,"'\''","&apos;")' \
    then put '$descrizione=gsub($descrizione,"\"","&quot;")' "$folder"/processing/delibereLeggi.csv

  mlr --c2t --quote-none head -n 30 then cut -f numero,descrizione,file,RSSdate "$folder"/processing/delibereLeggi.csv | tail -n +2 >"$folder"/processing/delibereLeggi.tsv

  # conteggia numero righe file di output
  numeroRighe=$(wc <"$folder"/processing/delibereLeggi.tsv -l)

  # se sono più di due procedi con la creazione del feed
  if [ "$numeroRighe" -gt 26 ]; then

    # imposta ritorni a capo in modalità Linux
    dos2unix "$folder"/processing/delibereLeggi.tsv

    # crea una copia del template del feed
    cp "$folder"/risorse/feedTemplate.xml "$folder"/processing/delibereLeggi_feed.xml

    # inserisci gli attributi di base nel feed
    xmlstarlet ed -L --subnode "//channel" --type elem -n title -v "$titolo" "$folder"/processing/delibereLeggi_feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n webMaster -v "$webMaster" "$folder"/processing/delibereLeggi_feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n description -v "$descrizione" "$folder"/processing/delibereLeggi_feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n link -v "$selflink" "$folder"/processing/delibereLeggi_feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n "atom:link" -v "" -i "//*[name()='atom:link']" -t "attr" -n "rel" -v "self" -i "//*[name()='atom:link']" -t "attr" -n "href" -v "$selflink" -i "//*[name()='atom:link']" -t "attr" -n "type" -v "application/rss+xml" "$folder"/processing/delibereLeggi_feed.xml

    # leggi in loop i dati del file TSV e usali per creare nuovi item nel file XML
    newcounter=0
    while IFS=$'\t' read -r numero descrizione file RSSdate; do
      newcounter=$(expr $newcounter + 1)
      xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
        --subnode "//item[$newcounter]" --type elem -n title -v "$numero" \
        --subnode "//item[$newcounter]" --type elem -n description -v "$descrizione" \
        --subnode "//item[$newcounter]" --type elem -n link -v "$file" \
        --subnode "//item[$newcounter]" --type elem -n pubDate -v "$RSSdate" \
        --subnode "//item[$newcounter]" --type elem -n guid -v "$file" \
        "$folder"/processing/delibereLeggi_feed.xml
    done <"$folder"/processing/delibereLeggi.tsv

    # copia il feed nella cartella pubblica
    cp "$folder"/processing/delibereLeggi_feed.xml "$folder"/docs/

    # copia tabella base nella cartella pubblica
    cp "$folder"/processing/delibereLeggi.csv "$folder"/docs/
  fi
fi
