# Hausarbeit 30100 Big Data (Kevin Südmersen)

[TOC]



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

![uebung_24.png](uebung_24.png)

Zuerst wird die Subquery `SELECT artnr FROM sales` ausgeführt, die Ergebnismenge in der Datei `output_file_1` zwischengespeichert, und dann werden nur die Artikel aus der Tabelle `artikel` genommen, die in `output_file_1` vorkommen. 

## Übung 2.5 

Der Code mit Erklärungen befindet sich in [diesem Notebook](https://github.com/kevinsuedmersen/hadoop-sandbox/blob/master/jupyter-spark/work/assignments/uebung_25_rjdbc_hive.ipynb).

TODO: Kann ich das alles hierunter löschen? 

### Laden der Daten in Hive

Zuerst habe ich die Daten der Kaggle Challenge heruntergeladen und in das Volume der Namenode hineinkopiert, sodass es automatisch in das Dateisystem des Namenode Containers durchgeleitet wird. Danach habe ich auf der Kommandozeile der Namenode den Befehl `hadoop fs -mkdir -p workspace/eating_and_health` ausgeführt um ein Verzeichnis im HDFS zu erstellen, sodass ich direkt im Anschluss mittels `hadoop fs -copyFromLocal <path_to_local_kaggle_files> workspace/eating_and_health/` die Daten ins HDFS hineinkopieren konnte. 

Danach habe ich über das UI von Hue die Daten vom HDFS in Hive geladen, was in etwa folgendermaßen ausgesehen hat

![uebung_251](uebung_251.PNG)

und im nächsten Schritt so

![uebung_252](uebung_252.PNG)

Danach konnte man auch feststellen, dass die Daten im HDFS nun in das Verzeichnis `/user/hive/warehouse/ehresp_2014/ehresp_2014.csv` *verschoben* wurden, also werden die Daten von nun an von Hive verwaltet. 

### Cloudera Hive Treiber Installation

Wie in der Vorlesung beschrieben, habe ich den aktuellsten Hive JDBC Treiber von der [Cloudera Webseite](https://www.cloudera.com/downloads/connectors/hive/jdbc/2-6-2.html) herunter geladen und alle sich darin befindenden Ordner extrahiert. Nun müssen diese Treiber Dateien für die Applikation, die auf Hive zugreifen will, zugänglich sein. In meinem Fall ist befindet sich die Applikation auf dem Jupyter Notebook Server, also in dem `jupyter-spark` Container in meinem `docker-compose` Netzwerk. Über ein Volume dieses Containers gelangen die Treiber Dateien dann in das `/drivers` Verzeichnis innerhalb dieses Containers. 

### Hive Zugriff über die Applikation

Im `jupyter-spark` Container habe ich dann ein Jupyter Notebook mit R Kernel erstellt. Mittels

```R
# List all jar files in /drivers
cp = list.files(
    path=c('/drivers/ClouderaHiveJDBC-2.6.2.1002/ClouderaHiveJDBC4-2.6.2.1002'), 
    pattern='jar', 
    full.names=T, 
    recursive=T)
print(cp)
```

Werden alle `.jar` (Java Archive) Dateien innerhalb des Hive JDBC Treibers der Version `2.6.2` aufgelistet, was bei mir erstaunlicherweise nur eine einzige Datei gewesen ist, nämlich:

```R
[1] "/drivers/ClouderaHiveJDBC-2.6.2.1002/ClouderaHiveJDBC4-2.6.2.1002/HiveJDBC4.jar"
```

Danach wird mittels 

```R
# Connect to Hive
.jinit()
drv = JDBC(
    driverClass="com.cloudera.hive.jdbc4.HS2Driver", 
    classPath=cp) 
conn = dbConnect(
    drv, 
    "jdbc:hive2://hiveserver:10000/default;AuthMech=3", 
    "hive", 
    "hive", 
    identifier.quote=" ")
show_databases = dbGetQuery(conn, "show databases")
print(show_databases)

# Read the data from Hive (make sure to upload ehresp_2014 into Hive first)
em <- dbGetQuery(conn, "select * from default.ehresp_2014 where euexercise > 0 and erbmi > 0")
summary(em)
```

eine Verbindung zu Hive erstellt, wobei man beachten muss, dass der `host` im Connection String `hiveserver`, also der Container Name des Hive Servers ist, was funktioniert, weil der `jupyer-spark` und `hiveserver` Container beide im gleichen `docker-compose` Netzwerk sind. Im Anschluss werden die Daten der Tabelle `ehresp_2014` eingelesen. Hier ist vielleicht erwähnenswert, dass man im Big Data Kontext eigentlich keine ganzen Tabellen in den Hauptspeicher lesen sollte, aber da `ehresp_2014` eine relativ kleine Tabelle ist, macht das hier nicht so viel aus. 

Die Befehle um die Plots zu erzeugen und deren Ergebnisse sehen folgendermaßen aus:

![uebung_253](uebung_253.PNG)

![uebung_254](uebung_254.PNG)

![uebung_255](uebung_255.PNG)

## Übung 2.6

TODO: Siehe den Code, Erklärungen und Ergebnisse zu Übung 2.6 [in diesem Notebook]()

## Übung 2.7

### Tägliche unit_sales

Wie bereits in anderen Übungen beschrieben habe ich zuerst die Dateien `holiday_events.csv`, `items.csv`, `quito_stores_sample2016_2017.csv` und `transactions.csv` in den `namenode` Container, dann in das HDFS und dann mittels dem Hue UI in Hive geladen. Folgendes HiveQL Statement soll die täglichen `unit_sales` berechnen:

```sql
select sum(unit_sales) as sum_unit_sales, year(date_quito) as current_year, month(date_quito) as current_month, day(date_quito) as current_day 
from quito_stores_sample2016_2017 
where date_format(date_quito ,'u') = 4 
group by year(date_quito), month(date_quito), day(date_quito)
order by current_year, current_month, current_day;
```

Output: 

![uebung_2711](uebung_2711.PNG)

In Retroperspektive, kam mir obiges Statement ein bisschen umständlich vor (weil zuerst das Jahr, der Monat und der Tag extrahiert, und danach wieder nach Jahr, Monat und Tag gruppiert werden muss), habe ich im folgenden Statement wieder die Summe der `unit_sales` berechnet, aber dieses mal habe ich nach dem Datum gruppiert. 

```sql
select sum(unit_sales) as sum_unit_sales, date_quito 
from quito_stores_sample2016_2017 
where date_format(date_quito ,'u') = 4 
group by date_quito;
```

Output:

![uebung_2712](uebung_2712.PNG)

Der Output scheint mir komplett identisch zu sein. 

### Wöchentliche unit_sales

TODO: Folgendes Statement löschen?

HiveQL Statement:

```sql
select weekofyear(tr.date_trans) as week, sum(tr.transactions) as weekly_unit_sales 
from items inner join quito_stores_sample2016_2017 AS quito_store on quito_store.item_nbr_quito = items.item_nbr_item 
inner join transactions AS tr on tr.store_nbr_trans = quito_store.store_nbr_quito 
inner join holidays_events on holidays_events.datum_holi = tr.date_trans 
group by weekofyear(tr.date_trans) 
order by week;
```

Ergebnis:

```
week	weekly_unit_sales	
1	28567434275	
2	9830893906	
6	8730851354	
7	8149803877	
8	8729617503	
9	27677998583	
10	13910862599	
12	4080833575	
13	10579847436	
14	17302118505	
15	54653669532	
16	57646139981	
17	42643974148	
18	68828867443	
19	88542663017	
20	11272350430	
21	32300823752	
24	8108878613	
25	46405889614	
26	62945616169	
27	51432764895	
28	17027589597	
29	19450255582	
30	46223357002	
31	9531701329	
32	38449772542	
33	26209142984	
34	13882155606	
35	3979359634	
39	14157756766	
40	13135696715	
41	32857151812	
44	35150332788	
45	66891536748	
46	28736604080	
47	5014115514	
48	13026132482	
49	57633576346	
50	8591347588	
51	77485626478	
52	126260907220	
53	5832310146	
```

HiveQL Statement:

```sql
select weekofyear(date_trans) as week, sum(transactions) as weekly_unit_sales
from transactions
group by weekofyear(date_trans)
order by week;
```

Ergebnis:

```
week	weekly_unit_sales	
1	2904264	
2	2876856	
3	2828681	
4	2787688	
5	2890639	
6	2914532	
7	2944731	
8	2836890	
9	2947415	
10	2967329	
11	2889503	
12	2872067	
13	2893670	
14	2999954	
15	2919038	
16	2997701	
17	2884039	
18	3057556	
19	3031439	
20	2891410	
21	2835168	
22	3013612	
23	2966299	
24	2925681	
25	2861633	
26	2848133	
27	2998279	
28	2852663	
29	2851306	
30	2847369	
31	2986859	
32	2881863	
33	2472897	
34	2272435	
35	2312863	
36	2413073	
37	2282162	
38	2258478	
39	2231450	
40	2364076	
41	2279355	
42	2246341	
43	2205255	
44	2256071	
45	2348502	
46	2265909	
47	2284200	
48	2321219	
49	2479496	
50	2558796	
51	3016656	
52	2885163	
53	520281	
```

