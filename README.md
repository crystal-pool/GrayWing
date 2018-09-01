# Gray Wing

> Queries facts in SPARQL.

A rudimentary [*Crystal Pool*](https://crystalpool.cxuesong.com) Query service. This is the successor of [`GrayWing-Prolog`](https://github.com/CXuesong/GrayWing-Prolog), which allows you to query for entities & relations about [*Warriors*](https://en.wikipedia.org/wiki/Warriors_(novel_series)), a fiction series authored by Erin Hunter. With SPARQL query language, performing more complex query is possible.

The live site is <https://q.crystalpool.cxuesong.com/>. You may query for what we have on Crystal Pool with [SPAQL query language](https://en.wikipedia.org/wiki/SPARQL).

If you are new to this, note that Crystal Pool uses Wikibase, the same MediaWiki extension as in [Wikidata](https://www.wikidata.org/). You may found their [SPARQL language guide on Wikibooks](https://en.wikibooks.org/wiki/SPARQL). Basically the query syntax and even the namespace prefixes are the same with Wikidata. (I haven't figure out how to change the prefixes in a easy fashion for now. Oops. Later `wd:` might be replaced with `cp:`)

*Crystal Pool* is a structured knowledge-base for Warriors. The site is still constructing in progress; thus most of the relations are not available for query. For now it just include most of the kinship & allegiances. If you would like to  improve Crystal Pool Wiki, consider [requesting for an account](https://crystalpool.cxuesong.com/wiki/Special:RequestAccount). Thank you.

## See also

* [About *Crystal Pool*](https://crystalpool.cxuesong.com/wiki/Special:MyLanguage/Crystal_Pool:About)

## SPARQL Query Examples

The following query will show you all the cats who belongs or used to belong to [ThunderClan](https://crystalpool.cxuesong.com/wiki/Item:Q627), as well as their English labels (aka. names) and genders.

```sparql
SELECT ?cat ?name ?gender WHERE {
  ?cat    wdt:P3      wd:Q622;       # should be fictional cat character
          wdt:P76     wd:Q627.       # should belong to ThunderClan
  OPTIONAL {
    ?cat    rdfs:label  ?name.
    FILTER(lang(?name) = "en")
  }
  OPTIONAL {
    ?cat    wdt:P78     ?gender.
  }
}
```

