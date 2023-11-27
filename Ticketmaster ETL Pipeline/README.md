
# Ticketmaster ETL Pipeline

## Dataset

[Ticketmaster API](https://developer.ticketmaster.com/) was used to fetch raw data of events.

## Data ingestion

This [Python script](Python%20&%20SQL/ingest_data.py) creates a workflow of data ingestion by first using API to fetch information of events. Since the extracted data is returned as a nested JSON file, it needs to be flattened before being loaded into data warehouse. 

## Data transformation & modelling
Regarding data warehouse, I've decided to use Azure SQL Database to gain experience with the cloud version of SQL Server. From intializing a database in Azure portal to creating connection congfiguration with Python script to load the data.

(azure_data.png)

From the raw data, further [SQL transformation](Python%20&%20SQL/transform_data.sql) is carried out to rename the columns and recast values with date data type to a cleaner format. Star schema data modelling was also done in the data warehouse so that dimension and fact tables can be imported directly into Power BI to ensure model consistency in case it is shared among other users.

How the imported dimension and facts table are shown via Power BI:

![data_model](images/data_model.png)

## Data visualization
Lastly, data is visualized to show which events are available in the U.S. region and their detailed information on sales date, start date, venues, etc. as well as top selling events up-to-date.

![dashboard](images/dashboard.png)
