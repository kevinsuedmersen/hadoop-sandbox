# Dropping the airbnb database if it exists
docker exec mongo mongo --username=kevinsuedmersen --password=secret --host=mongo:27017 airbnb --authenticationDatabase=admin --eval="db.dropDatabase()"

# Loading data into the airbnb database. Remember that --file points to a file inside the mongo container
docker exec mongo mongoimport --username=kevinsuedmersen --password=secret --host=mongo:27017 --db=airbnb --collection=listings_and_reviews --authenticationDatabase=admin --file=/mongo-data/airbnb/listingsAndReviews.json
