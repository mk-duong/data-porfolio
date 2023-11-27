-- Rename columns
DROP VIEW IF EXISTS dbo.events_view;
GO

CREATE VIEW events_view AS
    SELECT
        name AS event_name
        , id AS event_id
        , url AS event_url
        , info
        , CAST("public_startDateTime" AS DATE) AS sales_start_date
        , CAST("public_endDateTime" AS DATE) AS sales_end_date
        , CAST("presales_temp_startDateTime" AS DATE) AS presales_start_date
        , CAST("presales_temp_endDateTime" AS DATE) AS presales_end_date
        , presales_temp_name AS presales_type
        , presales_temp_description AS presales_description
        , "start_localDate" AS event_start_date
        , "start_localTime" AS event_start_time
        , status_code
        , temp_segment_id AS segment_id
        , temp_segment_name AS segment_name
        , temp_genre_id AS genre_id
        , temp_genre_name AS genre_name
        , temp_subGenre_id as sub_genre_id
        , temp_subGenre_name AS sub_genre_name
        , temp_min AS price_min
        , temp_max AS price_max
        , venues_temp_name AS venue_name
        , venues_temp_id AS venue_id
        , "venues_temp_postalCode" AS venue_postal_code
        , venues_temp_city_name AS venue_city_name
        , venues_temp_state_name AS venue_state_name
        , "venues_temp_state_stateCode" AS venue_state_code
        , venues_temp_address_line1 AS venue_address
        , venues_temp_location_longitude AS venue_long
        , venues_temp_location_latitude AS venue_lat
        , attractions_temp_name AS attraction_name_1
        , attractions_temp_id AS attraction_id_1
        , attractions_1_name AS attraction_name_2
        , attractions_1_id AS attraction_id_2

    FROM [dbo].[events];
GO

-- Create FactsEvents
DROP VIEW IF EXISTS dbo.FactsEvents;
GO

CREATE VIEW FactsEvents AS
    SELECT 
        event_id
        , event_name
        , event_url
        , info
        , CASE WHEN sales_start_date = '1900-01-01' OR sales_start_date = '9999-12-31' THEN null 
            ELSE sales_start_date END AS sales_start_date
        , sales_end_date
        , presales_start_date
        , presales_end_date
        , presales_type
        , presales_description
        , event_start_date
        , event_start_time
        , status_code
        , segment_id
        , genre_name
        , sub_genre_id
        , price_min
        , price_max
        , venue_id
        , attraction_name_1
        , attraction_name_2
        , FLOOR(RAND() * (100 - 20 + 1) + 20) AS sales
    FROM events_view;
GO

-- Create DimAttraction
DROP VIEW IF EXISTS dbo.DimEvent;
GO

CREATE VIEW DimEvent AS
    SELECT DISTINCT event_id, event_name
    FROM events_view;
GO

-- Create DimSegement
DROP VIEW IF EXISTS dbo.DimSegement;
GO

CREATE VIEW DimSegement AS
    SELECT DISTINCT segment_id, segment_name
    FROM events_view;
GO

-- Create DimGenre
DROP VIEW IF EXISTS dbo.DimGenre;
GO

CREATE VIEW DimGenre AS
    SELECT DISTINCT genre_name
    FROM events_view;
GO

-- Create DimSubGenre
DROP VIEW IF EXISTS dbo.DimSubGenre;
GO

CREATE VIEW DimSubGenre AS
    SELECT DISTINCT sub_genre_id, sub_genre_name
    FROM events_view;
GO

-- Create DimVenue
DROP VIEW IF EXISTS dbo.DimVenue;
GO

CREATE VIEW DimVenue AS
    SELECT DISTINCT venue_id, venue_name, venue_address, venue_lat, venue_long, venue_postal_code, venue_state_code
    FROM events_view;
GO

-- Create DimCity
DROP VIEW IF EXISTS dbo.DimCity;
GO

CREATE VIEW DimCity AS
    SELECT DISTINCT
        venue_postal_code as postal_code
        , venue_city_name AS city_name
    FROM events_view;
GO

-- Create DimState
DROP VIEW IF EXISTS dbo.DimState;
GO

CREATE VIEW DimState AS
    SELECT DISTINCT
        venue_state_code as state_code
        , venue_state_name AS state_name
    FROM events_view;
GO

-- Create DimAttraction
DROP VIEW IF EXISTS dbo.DimAttraction;
GO

CREATE VIEW DimAttraction AS
    WITH union_view AS (
        SELECT DISTINCT
            attraction_name_1 AS attraction_name
        FROM events_view

        UNION

        SELECT DISTINCT
            attraction_name_2 AS attraction_name
        FROM events_view
    )

    SELECT *
    FROM union_view
    WHERE attraction_name IS NOT NULL;
GO