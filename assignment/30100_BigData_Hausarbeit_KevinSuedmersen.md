# Hausarbeit 30100 Big Data (Kevin Südmersen)

## Übung 2.1

Ein Hadoopcluster besteht aus 4 DataNodes mit den Parametern `blocksize` 256 MB und `splitsize` 512 MB. Es soll die Datei `kfz.txt` der Größe 1 TB verteilt werden.

### (1) Über welches Protokoll werden die Dateiblöcke verteilt?

SSH (Secure Shell)

### (2) Wie viele Mapper gibt es auf welchen Nodes?

Ein Mapper bearbeitet einen Split. Ein Split besteht aus 512 / 256 = 2​ Blöcken, also bearbeitet ein Mapper 2 Blöcke

Es gibt 1 TB / 512 MB = 2 Millionen Splits, die auf 4 Nodes verteilt sind, also auf jeder Node gibt es 500.000 Splits und deshalb 500.000 Mapper pro Node. 

### (3) Wie viele Dateiblöcke enthält jeder Node?

Es gibt 1 TB / 256 MB = 4 Millionen Blöcke, die auf 4 Nodes verteilt sind, also enthält jeder Node 1 Millionen Blöcke

## Übung 2.2

Welche Ausgabedaten liefern die Prozesse Map-, Shuffle- und Sort- und Reduce für das SELECT-Statement `SELECT count(identnr), identnr FROM kfz GROUP BY identnr` ?

Map Prozess

- Eingabe: Datei `kfz.txt`
- Ausgabe: Liste von Tupeln mit folgenden Key, Value `(identnr, 1)` Paaren: `[(1, 1), (1, 1), (2, 1), (1, 1)]`

Shuffle & Sort Prozess

- Eingabe: Key, Value Paare vom Map Prozess
- Sortiert und gruppiert nach `identnr`, also erzeugt dabei folgende Gruppen
  - `group(identnr == 1) = [(1, 1), (1, 1), (1, 1)]`
  - `group(identnr == 2) = [(2, 1)]`
- Ausgabe: 1 Datei pro `identnr`

Reduce Prozess

- Eingabe: Jeder Reduce Prozess bekommt eine Datei/Gruppe von der Ausgabe des Shuffle & Sort Prozesses
- Jeder Reducer berechnet die Summe der Values jeder Gruppe
- Ausgabe: 1 Datei mit den Spalten `count(identnr)` und `identnr`

## Übung 2.3

Um die SQL Abfragen dieser Aufgabe ausführen zu können, muss eine Tabelle mit Namen `verkaufteartikel` in Hive existieren. Um die Daten dieser Hive Tabelle in mein lokal installiertes Hadoop Cluster zu transferieren, habe ich im HDFS des Kubernetes Cluster der Hochschule nach einer Datei `verkaufteartikel` mittels `hadoop fs -find / -name "verkaufteartikel*"` gesucht. Danach habe ich die gefundenen Dateien mittels `hadoop fs -copyToLocal <location_of_verkaufteartikel_in_hdfs> <desired_location_on_host>` auf den Host des Hadoop Clusters kopiert, und danach habe ich die dazugehörigen Daten mittels WinSCP auf meinen lokalen Rechner kopiert. 

Die Daten in `verkaufteartikel ` sehen folgendermaßen aus:

```
2,2016-12-03,3
1,2017-04-17,24
2,2018-05-07,17
3,2019-09-12,33
4,2020-12-20,14
```

Diese Daten habe ich nun in die Namenode meines lokal installierten Hadoop Clusters kopiert und habe auf der Kommandozeile der Namenode den Befehl `hadoop fs -mkdir -p hadoop-data/verkaufteartikel` ausgeführt, um das Verzeichnis `hadoop-data/verkaufteartikel`im HDFS zu erzeugen. Danach habe ich mittels `hadoop fs -copyFromLocal verkaufteartikel.csv hadoop-data/verkaufteartikel/` die Daten in das gerade erzeugte Verzeichnis kopiert. 

Danach habe ich einen SQL Query Editor in dem Hue Dienst (Hue ist ein Cluster Management Dienst so ähnlich wie Ambari) geöffnet und mit dem SQL Statement 

```sql
-- Convert verkaufteartikel into a Hive table
CREATE EXTERNAL TABLE IF NOT EXISTS verkaufteartikel (
    id INT, 
    date_ DATE, 
    quantity INT)
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n' 
LOCATION '/user/root/hadoop-data/verkaufteartikel';
```

die Daten von `verkaufteartikel` in eine externe Hive Tabelle geladen. 

Nun konnte ich endlich die SQL Statements aus der Übungsaufgabe ausführen. Das Ergebnis der ersten SQL Abfrage 

```sql
EXPLAIN SELECT * 
FROM verkaufteartikel
WHERE date_ > '2017-01-01';
```

ist wie folgt:

```
Explain	
STAGE DEPENDENCIES:	
  Stage-0 is a root stage	
	
STAGE PLANS:	
  Stage: Stage-0	
    Fetch Operator	
      limit: -1	
      Processor Tree:	
        TableScan	
          alias: verkaufteartikel	
          Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
          Filter Operator	
            predicate: (date_ > 2017-01-01) (type: boolean)	
            Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
            Select Operator	
              expressions: id (type: int), date_ (type: date), quantity (type: int)	
              outputColumnNames: _col0, _col1, _col2	
              Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
              ListSink
```

- `TableScan` bedeutet, dass jede Zeile von `verkaufteartikel` einmal in den Hauptspeicher geladen werden musste (**TODO: Fragen ob das stimmt**)
- Der `Filter Operator` kommt durch die `WHERE` Klausel im SQL Statement zustande und behält nur die Zeilen von `verkaufteartikel`, die die dazugehörige Bedingung erfüllen
- `predicate (date_ > 2017-01-01)` ist die zu der `WHERE` Klausel gehörende Bedingung
- `Select Operator` ist eine Projektion auf gewisse Spaltennamen, in unserem Fall wurden mittels `*` alle Spaltennamen selektiert, und deshalb sind in `expressions` alle Spaltennamen aufgeführt. 

Nun zur 2. SQL Abfrage. Das Ergebnis der Abfrage

```sql
EXPLAIN SELECT date_, count(*) 
FROM verkaufteartikel
GROUP BY date_;
```

ist folgendes:

```
Explain	
STAGE DEPENDENCIES:	
  Stage-1 is a root stage	
  Stage-0 depends on stages: Stage-1	
	
STAGE PLANS:	
  Stage: Stage-1	
    Map Reduce	
      Map Operator Tree:	
          TableScan	
            alias: verkaufteartikel	
            Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
            Select Operator	
              expressions: date_ (type: date)	
              outputColumnNames: date_	
              Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
              Group By Operator	
                aggregations: count()	
                keys: date_ (type: date)	
                mode: hash	
                outputColumnNames: _col0, _col1	
                Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
                Reduce Output Operator	
                  key expressions: _col0 (type: date)	
                  sort order: +	
                  Map-reduce partition columns: _col0 (type: date)	
                  Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
                  value expressions: _col1 (type: bigint)	
      Reduce Operator Tree:	
        Group By Operator	
          aggregations: count(VALUE._col0)	
          keys: KEY._col0 (type: date)	
          mode: mergepartial	
          outputColumnNames: _col0, _col1	
          Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
          File Output Operator	
            compressed: false	
            Statistics: Num rows: 1 Data size: 79 Basic stats: COMPLETE Column stats: NONE	
            table:	
                input format: org.apache.hadoop.mapred.SequenceFileInputFormat	
                output format: org.apache.hadoop.hive.ql.io.HiveSequenceFileOutputFormat	
                serde: org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe	
	
  Stage: Stage-0	
    Fetch Operator	
      limit: -1	
      Processor Tree:	
        ListSink	
```

- `Map Reduce Tree`
    - Hier wird wieder zuerst ein `TableScan` gemacht, und es wird auf die Spalte `date_` projiziert, da dies die einzige Spalte ist, die man braucht, um das Ergebnis der Abfrage zu bekommen
    - Im `Group By Operator` (Shuffle & Sort Prozess) wird u.a. nach der `date_` Spalte gruppiert. Pro Datum gibt es eine Gruppe. In unserem Fall gibt es genau 5 Gruppen, die jeweils ein einziges Datum beinhalten, nämlich:
        - 2016-12-03
        - 2017-04-17
        - 2018-05-07
        - 2019-09-12
        - 2020-12-20
- `Reduce Operator Tree`
    - Hier wird für jede der obigen Gruppen nun die Aggregatsfunktion `count(VALUE._col0)` angewendet



## Übung 2.4

Hadoop verteilt Dateien und Spark verteilt Programme und SQL Abfragen, insbesondere JOINs. Aus dem Programm wird ein Directed Acyclic Graph (DAG) generiert und es wird versucht diesen DAG zu parallelisieren. Ein DAG ist ein Berechnungsgraph, der ein Anfang und ein Ende hat (also keine Zyklen), der den Programmablauf darstellt und diesen ausführt. 

Der DAG zu der SQL Abfrage 

```sql
SELECT * FROM artikel WHERE artnr IN (SELECT artnr FROM sales)
```

sieht folgendermaßen aus:

![uebung_2_4](C:\Users\kevin\Google Drive\education\uni\msc_data_science\30100_big_data\hausarbeit\uebung_2_4.png)

Zuerst wird die Subquery `SELECT artnr FROM sales` ausgeführt, die Ergebnismenge in der Datei `output_file_1` zwischengespeichert, und dann werden nur die Artikel aus der Tabelle `artikel` genommen, die in `output_file_1` vorkommen. 