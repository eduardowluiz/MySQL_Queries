USE Chinook;


-- View identifying the top spending customer in each country. Results from highest spent to lowest.
CREATE VIEW TopCustomerPerCountry AS
WITH RankCustomerPerCountry AS(
SELECT 
	c.Country AS Country,
	CONCAT(C.FirstName, ' ', C.LastName) AS Customer, 
    SUM(i.Total) AS TotalSpent,
    RANK() OVER (PARTITION BY c.Country ORDER BY SUM(i.Total) DESC) AS SpendingRank
FROM Customer c
LEFT JOIN Invoice i USING(CustomerId)
GROUP BY c.Country, Customer
)
SELECT Country, Customer, TotalSpent
FROM RankCustomerPerCountry
WHERE SpendingRank = 1
ORDER BY Country;

SELECT * FROM TopCustomerPerCountry;


-- View showing the top 5 selling artists of the top selling genre
CREATE VIEW TopArtistsFromTopGenre AS
WITH RankedGenres AS (
	SELECT 
		g.Name AS Genre,
		SUM(il.Quantity),
		RANK() OVER (ORDER BY SUM(il.Quantity) DESC) AS SalesRank
	FROM InvoiceLine il
	LEFT JOIN Track t USING (TrackId)
	JOIN Album al USING (AlbumId)
	JOIN Artist ar USING (ArtistId)
	JOIN Genre g USING(GenreId)
	GROUP BY g.Name
),
TopGenre AS (
SELECT Genre AS TopGenre
FROM RankedGenres
WHERE SalesRank = 1
),
ArtistsRanked AS (
SELECT
	g.Name AS Genre,
	ar.Name AS Artist,
    SUM(il.Quantity),
    RANK() OVER (PARTITION BY g.Name ORDER BY SUM(il.Quantity) DESC) AS ArtistRank
FROM InvoiceLine il
LEFT JOIN Track t USING (TrackId)
JOIN Album al USING (AlbumId)
JOIN Artist ar USING (ArtistId)
JOIN Genre g USING(GenreId)
WHERE g.Name IN (SELECT * FROM TopGenre)
GROUP BY g.Name, ar.Name
)
SELECT * FROM ArtistsRanked WHERE ArtistRank <= 5;

SELECT * FROM TopArtistsFromTopGenre;


-- Stored procedure retrievesing all orders and corresponding items acquired by the customer who placed the order
DELIMITER $$
CREATE PROCEDURE OrdersFromInvoice (IN InputInvoiceId INT)

BEGIN
    SELECT 
		il.InvoiceId,
        il.InvoiceLineId,
        t.TrackId,
        t.Name
    FROM InvoiceLine AS il
		JOIN Track t USING (TrackId)
    WHERE il.InvoiceId = InputInvoiceId;
END $$

DELIMITER ;

CALL OrdersFromInvoice(11);


-- Stored procedure retrieving sales data from a given date range
DELIMITER $$

CREATE PROCEDURE GetSalesByDateRange(IN startDate DATE, IN endDate DATE)
BEGIN
    SELECT
        InvoiceId,
        CustomerId,
        InvoiceDate,
        BillingCity,
        Total
    FROM
        Invoice
    WHERE
        InvoiceDate BETWEEN startDate AND endDate
    ORDER BY
        InvoiceDate;
END $$

DELIMITER ;

CALL GetSalesByDateRange('2021-12-01', '2021-12-31');


-- Stored function calculateing the average invoice amount for a given country
DELIMITER $$

CREATE FUNCTION GetAvgInvoiceCountry(InputCountry VARCHAR(50))
RETURNS DECIMAL(10,2)

DETERMINISTIC

BEGIN
    DECLARE AvgInvoice DECIMAL(10,2);
    
    SELECT AVG(Total) INTO AvgInvoice
    FROM Invoice 
    WHERE BillingCountry = InputCountry
    GROUP BY BillingCountry;
    
    RETURN AvgInvoice;
END $$
DELIMITER ;

SELECT GetAvgInvoiceCountry('Germany') AS AvgInvoice;

-- Stored function returning the best-selling artist in a specified genre
DELIMITER $$

CREATE FUNCTION GetTopArtistOfGenre(InputGenre VARCHAR(50))
RETURNS VARCHAR(50)

DETERMINISTIC

BEGIN
    DECLARE OutputArtist VARCHAR(50);

WITH TopArtistsPerGenre AS (
	SELECT 
		g.Name AS Genre, 
		ar.Name AS Artist, 
		SUM(il.Quantity) AS NumberOfSales,
		RANK() OVER (PARTITION BY g.Name ORDER BY SUM(il.Quantity) DESC) AS ArtistRank
	FROM InvoiceLine il
	LEFT JOIN Track t USING(TrackId)
	LEFT JOIN Album al USING(AlbumId)
	LEFT JOIN Artist ar USING (ArtistId)
	LEFT JOIN Genre g USING(GenreId)
	GROUP BY Genre, Artist
),
TopArtist AS (
SELECT Genre, Artist AS TopArtist, NumberOfSales
FROM TopArtistsPerGenre
WHERE ArtistRank = 1
)
SELECT TopArtist INTO OutputArtist
FROM TopArtist
WHERE Genre = InputGenre;

RETURN OutputArtist;
END $$
DELIMITER ;

SELECT GetTopArtistOfGenre('Jazz') AS TopArtist;


-- Stored function calculating the total amount that a customer spent with the company

DROP FUNCTION IF EXISTS TotalSpentPerCustomer ;

DELIMITER $$

CREATE FUNCTION TotalSpentPerCustomer(InputCustomerID INT)
RETURNS DECIMAL(10,2)

DETERMINISTIC

BEGIN
    DECLARE TotalSpent DECIMAL(10,2);

SELECT 
    SUM(i.Total) AS TotalSpent INTO TotalSpent
FROM
	Invoice i 
JOIN
	Customer c USING (CustomerId)
WHERE
	i.CustomerId = InputCustomerID;
    
RETURN TotalSpent;
END $$
DELIMITER ;

SELECT TotalSpentPerCustomer(9) AS TotalSpentByCustomer;


-- Stored function getting the average song length for an album
DROP FUNCTION IF EXISTS AvgSongLengthPerAlbum;

DELIMITER $$

CREATE FUNCTION AvgSongLengthPerAlbum(AlbumName VARCHAR(50))
RETURNS DECIMAL(10,2)

DETERMINISTIC

BEGIN
    DECLARE AvgSongLength DECIMAL(10,2);

SELECT ROUND(AVG(t.Milliseconds)/60000,2) INTO AvgSongLength
FROM Track t
LEFT JOIN Album a USING(AlbumId)
GROUP BY a.Title
HAVING a.Title = AlbumName;

RETURN AvgSongLength;
END $$
DELIMITER ;

SELECT AvgSongLengthPerAlbum('Na Pista') AS AvgSongLength;


-- Stored function returning the most popular genre for a given country
DROP FUNCTION IF EXISTS TopGenrePerCountry;
DELIMITER $$

CREATE FUNCTION TopGenrePerCountry(CountryName VARCHAR(50))
RETURNS VARCHAR(50)

DETERMINISTIC

BEGIN
    DECLARE TopGenre VARCHAR(50);

WITH TopGenresPerCountry AS (
SELECT 
	i.BillingCountry AS Country, 
    g.Name as Genre,
    SUM(il.UnitPrice * il.Quantity) AS NumberOfSales,
    RANK() OVER (PARTITION BY i.BillingCountry ORDER BY SUM(il.Quantity) DESC) AS ArtistRank
FROM InvoiceLine il
LEFT JOIN Invoice i USING(InvoiceId)
LEFT JOIN Track t USING(TrackId)
LEFT JOIN Genre g USING(GenreId)
GROUP BY i.BillingCountry, g.Name
)
SELECT Genre INTO TopGenre
FROM TopGenresPerCountry
WHERE ArtistRank = 1 AND Country = CountryName;

RETURN TopGenre;
END $$
DELIMITER ;

SELECT TopGenrePerCountry('Chile') AS TopGenre;
