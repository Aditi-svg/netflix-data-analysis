-- ================================================================
-- Netflix Database Project
-- This script creates and loads tables for analyzing Netflix data
-- ================================================================

-- Step 1: Create the database
CREATE DATABASE netflix_db;

-- Step 2: Switch to the new database
USE netflix_db;

-- Step 3: Create main table for Netflix titles
CREATE TABLE netflix_titles (
    show_id VARCHAR(20) PRIMARY KEY,   -- Unique ID for each title
    type VARCHAR(50),                  -- Type of content: 'Movie' or 'TV Show'
    title VARCHAR(255),                -- Title of the show or movie
    date_added DATE,                   -- Date added to Netflix
    release_year INT,                  -- Year of release
    rating VARCHAR(20),                -- Age rating (e.g., TV-MA, PG-13)
    duration_value INT,                -- Duration value (e.g., 90 for 90 minutes)
    duration_unit VARCHAR(20)          -- Unit of duration (e.g., 'min', 'Season')
);

-- Step 4: Load Netflix titles data from CSV file
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/netflix_titles_cleanexx.csv'
INTO TABLE netflix_titles
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Verify number of rows imported
SELECT COUNT(*) FROM netflix_titles;

-- Check MySQL secure_file_priv setting (controls import/export directory)
SHOW VARIABLES LIKE "secure_file_priv";

-- Inspect table creation statement
SHOW CREATE TABLE netflix_titles;


-- ================================================================
-- Create and Load Netflix Countries Table
-- ================================================================

CREATE TABLE netflix_countries (
    show_id VARCHAR(20),                -- Show ID linked to netflix_titles
    country VARCHAR(100),               -- Country where the show/movie was produced
    FOREIGN KEY (show_id) REFERENCES netflix_titles(show_id)
);

-- Load countries data
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/netflix_country.csv'
INTO TABLE netflix_countries
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Verify number of rows imported
SELECT COUNT(*) FROM netflix_countries;


-- ================================================================
-- Create and Load Netflix Genres Table
-- ================================================================

CREATE TABLE netflix_genres (
    show_id VARCHAR(20),                -- Show ID linked to netflix_titles
    genre VARCHAR(100),                 -- Genre name
    FOREIGN KEY (show_id) REFERENCES netflix_titles(show_id)
);

-- Load genres data
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/netflix_genre.csv'
INTO TABLE netflix_genres
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Verify number of rows imported
SELECT COUNT(*) FROM netflix_genres;


-- ================================================================
-- Data Analysis Queries
-- ================================================================

-- 1. Top 10 genres overall
SELECT genre, COUNT(*) AS genre_count
FROM netflix_genres
GROUP BY genre
ORDER BY genre_count DESC
LIMIT 10;
-- Example insight: International Movies appear most frequently.

-- 2. Top 10 countries with the most Netflix content
SELECT country, COUNT(*) AS count_of_shows
FROM netflix_countries
GROUP BY country
ORDER BY count_of_shows DESC
LIMIT 10;
-- Example insight: United States leads, followed by India.

-- 3. Distribution of Movies vs TV Shows
SELECT n.type, COUNT(*) AS total_count
FROM netflix_titles n
GROUP BY n.type;

-- 4. Number of titles released per year
SELECT release_year, COUNT(title) AS number_of_titles
FROM netflix_titles
GROUP BY release_year
ORDER BY number_of_titles DESC;
-- Example insight: 2018 saw the highest number of releases.

-- 5. Top genre in each country
SELECT country, genre, genre_count
FROM (
    SELECT c.country, 
           g.genre, 
           COUNT(*) AS genre_count,
           RANK() OVER (PARTITION BY c.country ORDER BY COUNT(*) DESC) AS genre_rank
    FROM netflix_countries c
    JOIN netflix_genres g ON c.show_id = g.show_id
    GROUP BY country, genre
) AS ranked
WHERE genre_rank = 1
ORDER BY country;

-- 6. Most common rating by country
SELECT country, rating, rating_rank 
FROM (
    SELECT c.country, 
           t.rating,
           COUNT(*) AS rating_count,
           RANK() OVER (PARTITION BY c.country ORDER BY COUNT(*) DESC) AS rating_rank
    FROM netflix_countries c 
    JOIN netflix_titles t ON c.show_id = t.show_id
    GROUP BY country, rating
) AS rated
WHERE rating_rank = 1
ORDER BY country;

-- 7. Average duration of movies by genre
SELECT TRIM(g.genre) AS genre, 
       AVG(t.duration_value) AS average_duration
FROM netflix_genres g 
JOIN netflix_titles t ON g.show_id = t.show_id
WHERE t.type = "Movie"
GROUP BY TRIM(g.genre)
ORDER BY average_duration DESC;

-- 8. Top 3 genres per country
WITH genre_count AS (
    SELECT c.country, 
           TRIM(genre) AS genre, 
           COUNT(*) AS number_of_titles,
           DENSE_RANK() OVER (PARTITION BY c.country ORDER BY COUNT(*) DESC) AS ranked
    FROM netflix_countries c 
    JOIN netflix_genres g ON c.show_id = g.show_id
    GROUP BY country, genre
)
SELECT country, genre, number_of_titles, ranked
FROM genre_count
WHERE ranked < 4;

-- 9. Titles added year-over-year with difference
WITH yearly AS (
    SELECT release_year, COUNT(*) AS titles
    FROM netflix_titles
    GROUP BY release_year
    ORDER BY release_year
)
SELECT release_year, 
       titles, 
       LAG(titles, 1) OVER (ORDER BY release_year DESC) AS last_year,
       titles - LAG(titles, 1) OVER (ORDER BY release_year DESC) AS diff
FROM yearly;

-- 10. First genre released in each country
WITH genre AS (
    SELECT TRIM(g.genre) AS genre, 
           c.country,
           t.release_year 
    FROM netflix_genres g
    JOIN netflix_countries c ON g.show_id = c.show_id
    JOIN netflix_titles t ON g.show_id = t.show_id
)
SELECT DISTINCT country, 
       release_year,
       FIRST_VALUE(genre) OVER (PARTITION BY country ORDER BY release_year) AS first_genre
FROM genre;
