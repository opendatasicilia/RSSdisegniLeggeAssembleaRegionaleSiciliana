# RSSdisegniLeggeAssembleaRegionaleSiciliana

## Punti base

Aprire pagina query generica che mostra ultimi disegni legge, salvando cookie 

```
curl -c ./cookie "https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL%29"
```

Salvare risultato query con

```
curl -b ./cookie "https://w3.ars.sicilia.it/icaro/shortList.jsp?_=" >./risultati.html
```

Estrarre di ogni risultato:

- Titolo
- LEGISL.
- NUMERO
- DATA

In modo da costruire URL assouluti come <https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=%2817.LEGISL+E+%28485%29.NUMDDL%29>, che sarebbe

```
https://w3.ars.sicilia.it/icaro/default.jsp?icaDB=221&icaQuery=(17.LEGISL E (485).NUMDDL)
```
