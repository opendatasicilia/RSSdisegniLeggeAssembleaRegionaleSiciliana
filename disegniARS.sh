#!/bin/bash

### requisiti ###
# miller https://github.com/johnkerl/miller
# scrape-cli https://github.com/aborruso/scrape-cli
# jq https://stedolan.github.io/jq/
# xq https://github.com/kislyuk/yq
# xmlstarlet http://xmlstar.sourceforge.net/
### requisiti ###

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/rawdata
mkdir -p "$folder"/processing
mkdir -p "$folder"/docs

rm "$folder"/rawdata/*

### scarica dati di base ###

URLqueryBase="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL%29"

# leggi la risposta HTTP del sito
code=$(curl -s -L -o /dev/null -w "%{http_code}" ''"$URLqueryBase"'')

# se il sito è raggiungibile scarica i dati
if [ $code -eq 200 ]; then

  # fai la query di base e imposta cookie
  curl -skL -c "$folder"/rawdata/cookie "$URLqueryBase" >/dev/null

  ### Pag 1

  URLrisultatiBasePag1="https://w3.ars.sicilia.it/icaro/shortList.jsp?setPage=1&_="

  # leggi cooki e ricevi lista risultati
  curl -skL -b "$folder"/rawdata/cookie "$URLrisultatiBasePag1" >"$folder"/rawdata/risultati_01.html

  # estrai la lista dei risultati in formato JSON
  scrape <"$folder"/rawdata/risultati_01.html -be '//ul[@id="shortListTable"]/li[position() > 1]' | xq . >"$folder"/rawdata/risultati_01.json

  # estrai i valori dei 4 campi
  jq <"$folder"/rawdata/risultati_01.json -r '.html.body.li[]|{legislatura:.div[0].p.strong["#text"],numero:.div[1].p.strong["#text"],data:.div[2].p.strong["#text"],titolo:.div[4].h3.a["#text"]}' | mlr --j2c unsparsify >"$folder"/rawdata/lista_01.csv

  # normalizza data e aggiungi data RSS
  mlr -I --csv clean-whitespace then put '$data=sub($data,"^([^\.]+)(\.)([^\.]+)(\.)([^\.]+)$","20\5-\3-\1")' then put '$RSSdate = strftime(strptime($data, "%Y-%m-%d"),"%a, %d %b %Y %H:%M:%S %z")' "$folder"/rawdata/lista_01.csv

  # aggiungi URL disegno legge
  mlr -I --csv head then put '$URL="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%28".$legislatura.".LEGISL+E+%28".$numero."%29.NUMDDL%29"' "$folder"/rawdata/lista_01.csv

  # rimuovi eventuali righe duplicate
  mlr -I --csv uniq -a "$folder"/rawdata/lista_01.csv

  ### Pag 2

  URLrisultatiBasePag2="https://w3.ars.sicilia.it/icaro/shortList.jsp?setPage=2&_="

  # leggi cooki e ricevi lista risultati
  curl -skL -b "$folder"/rawdata/cookie "$URLrisultatiBasePag2" >"$folder"/rawdata/risultati_02.html

  # estrai la lista dei risultati in formato JSON
  scrape <"$folder"/rawdata/risultati_02.html -be '//ul[@id="shortListTable"]/li[position() > 1]' | xq . >"$folder"/rawdata/risultati_02.json

  # estrai i valori dei 4 campi
  jq <"$folder"/rawdata/risultati_02.json -r '.html.body.li[]|{legislatura:.div[0].p.strong["#text"],numero:.div[1].p.strong["#text"],data:.div[2].p.strong["#text"],titolo:.div[4].h3.a["#text"]}' | mlr --j2c unsparsify >"$folder"/rawdata/lista_02.csv

  # normalizza data e aggiungi data RSS
  mlr -I --csv clean-whitespace then put '$data=sub($data,"^([^\.]+)(\.)([^\.]+)(\.)([^\.]+)$","20\5-\3-\1")' then put '$RSSdate = strftime(strptime($data, "%Y-%m-%d"),"%a, %d %b %Y %H:%M:%S %z")' "$folder"/rawdata/lista_02.csv

  # aggiungi URL disegno legge
  mlr -I --csv head then put '$URL="https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%28".$legislatura.".LEGISL+E+%28".$numero."%29.NUMDDL%29"' "$folder"/rawdata/lista_02.csv

  # rimuovi eventuali righe duplicate
  mlr -I --csv uniq -a "$folder"/rawdata/lista_02.csv

  # unisci dati
  mlr --csv uniq -a then sort -r data -nr numero "$folder"/rawdata/lista_02.csv "$folder"/rawdata/lista_01.csv >"$folder"/rawdata/lista.csv

  # conteggia numero righe file di output
  numeroRighe=$(wc <"$folder"/rawdata/lista.csv -l)

  # se sono più di due procedi con la creazione del feed
  if [ "$numeroRighe" -gt 2 ]; then

    # copia lista scaricata in cartella pubblica
    cp "$folder"/rawdata/lista.csv "$folder"/docs/latest.csv

    # se non esiste CSV storico crealo
    if [ ! -f "$folder"/docs/storico.csv ]; then
      cp "$folder"/docs/latest.csv "$folder"/docs/storico.csv
    fi

    cp "$folder"/docs/storico.csv "$folder"/docs/tmp.csv

    # aggiorna storico
    mlr --csv uniq -a then sort -r data -nr numero "$folder"/docs/tmp.csv "$folder"/docs/latest.csv >"$folder"/docs/storico.csv

    ### crea RSS ###

    # anagrafica RSS
    titolo="Disegni di legge dell'Assemblea Regionale Siciliana | a cura di OpenDataSicilia"
    descrizione="Un RSS per essere aggiornato sui disegni di legge dell'Assemblea Regionale Siciliana"
    webMaster="info@opendatasicilia.it (Open Data Sicilia)"
    selflink="https://opendatasicilia.github.io/RSSdisegniLeggeAssembleaRegionaleSiciliana/feed.xml"

    # crea file TSV sorgente dati RSS e fai pulizia caratteri
    mlr --c2t --quote-none sort -r data \
      then put '$titolo=gsub($titolo,"<","&lt")' \
      then put '$titolo=gsub($titolo,">","&gt;")' \
      then put '$titolo=gsub($titolo,"&","&amp;")' \
      then put '$URL=gsub($URL,"&","&amp;")' \
      then put '$titolo=gsub($titolo,"'\''","&apos;")' \
      then put '$titolo=gsub($titolo,"\"","&quot;")' "$folder"/rawdata/lista.csv |
      tail -n +2 >"$folder"/rawdata/rss.tsv

    # imposta ritorni a capo in modalità Linux
    dos2unix "$folder"/rawdata/rss.tsv

    # crea una copia del template del feed
    cp "$folder"/risorse/feedTemplate.xml "$folder"/processing/feed.xml

    # inserisci gli attributi di base nel feed
    xmlstarlet ed -L --subnode "//channel" --type elem -n title -v "$titolo" "$folder"/processing/feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n description -v "$descrizione" "$folder"/processing/feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n link -v "$selflink" "$folder"/processing/feed.xml
    xmlstarlet ed -L --subnode "//channel" --type elem -n "atom:link" -v "" -i "//*[name()='atom:link']" -t "attr" -n "rel" -v "self" -i "//*[name()='atom:link']" -t "attr" -n "href" -v "$selflink" -i "//*[name()='atom:link']" -t "attr" -n "type" -v "application/rss+xml" "$folder"/processing/feed.xml

    # leggi in loop i dati del file TSV e usali per creare nuovi item nel file XML
    newcounter=0
    while IFS=$'\t' read -r legislatura numero data titolo RSSdate URL; do
      newcounter=$(expr $newcounter + 1)
      xmlstarlet ed -L --subnode "//channel" --type elem -n item -v "" \
        --subnode "//item[$newcounter]" --type elem -n title -v "Disegno di legge $numero" \
        --subnode "//item[$newcounter]" --type elem -n description -v "$titolo" \
        --subnode "//item[$newcounter]" --type elem -n link -v "$URL" \
        --subnode "//item[$newcounter]" --type elem -n pubDate -v "$RSSdate" \
        --subnode "//item[$newcounter]" --type elem -n guid -v "$URL" \
        "$folder"/processing/feed.xml
    done <"$folder"/rawdata/rss.tsv

    # copia il feed nella cartella pubblica
    cp "$folder"/processing/feed.xml "$folder"/docs/
  fi
fi
