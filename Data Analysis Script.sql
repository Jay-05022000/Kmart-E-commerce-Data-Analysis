
/*
Data Cleaning & Transformation:

1) Standardize Order Date column. 
-  True Order Date format : MM-DD-YY HH:MM ,72775 rows have Order Date in %%MM-DD-YY HH:MM format. */

-- Trim unnecessary characters of unformatted dates.

UPDATE [dbo].[Combined Sales Data] 
SET [Order Date]  = SUBSTRING([Order Date],3,LEN([Order Date]))  
WHERE [Order Date] LIKE '20%%-%%-%% %%:%%';
 
-- Creat Purchase_Date column.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Purchase_Date AS SUBSTRING([Order Date],1,8)

-- Creat Purchase_Time column.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Purchase_Time AS SUBSTRING([Order Date],10,LEN([Order Date]))

-- Creat Purcahse_Month column.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Purchase_Month AS SUBSTRING([Order Date],1,2)

-- Create Purchase_Day column.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Purchase_Day AS PARSENAME(REPLACE([Order Date],'-','.'),2)

-- Create Generated_Revenue column.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Generated_Revenue AS TRY_CAST([Price Each] AS FLOAT) * TRY_CAST([Quantity Ordered] AS FLOAT)

-- Create Cust_Street_Add column. 

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Cust_Street_Add AS REPLACE(SUBSTRING([Purchase Address],2,CHARINDEX(',',[Purchase Address])),',','') --REPLACE FUNCTION IS USED TO REMOVE UNNECESSARY ',' AVAILABLE AT THE END.

-- Create City column.

 ALTER TABLE  [dbo].[Combined Sales Data]
 ADD City AS SUBSTRING([Purchase Address],CHARINDEX(',',[Purchase Address]) + 2,LEN([Purchase Address])-CHARINDEX(',',[Purchase Address])-12)

-- Create Pincode column.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Pincode As REPLACE(SUBSTRING([Purchase Address],LEN([Purchase Address]) - 8,LEN([Purchase Address])),'"','') -- Replace is for removing unwanted '"' at the end.
 
-- Create State Column.

ALTER TABLE [dbo].[Combined Sales Data]
ADD State As SUBSTRING([Purchase Address] , CHARINDEX(',', [Purchase Address] , CHARINDEX(',',[Purchase Address] ) + 1) + 2, 2)
 
-- Create Purchase_Time_Slot column.

ALTER TABLE [dbo].[Combined Sales Data]
ADD Purchase_Time_Slot AS  SUBSTRING([Order Date],CHARINDEX(' ',[Order Date]) + 1,2 ) + '-' +  TRY_CONVERT(NVARCHAR(50),TRY_CAST( SUBSTRING([Order Date],CHARINDEX(' ',[Order Date]) + 1,2 ) AS INT) + 1)

SELECT *
FROM [dbo].[Combined Sales Data]
 



-- Analysis starts from here.

-- 1) Which day of the month recorded the highest sales? 
 
 select [Purchase_Month],count([Purchase_Month]) -- we have one record that contains 'Or' in Purchase_Month column.
 from [dbo].[Combined Sales Data]
 group by [Purchase_Month]
 order by [Purchase_Month]
 
 -- Remove that record.

 DELETE FROM [dbo].[Combined Sales Data]
 WHERE [Purchase_Month] = 'Or'

 
 SELECT [Purchase_Month], ROUND(SUM([Generated_Revenue]),2) AS Total_Revenue_Per_Month
 from [dbo].[Combined Sales Data]
 group by [Purchase_Month]
 ORDER BY ROUND(SUM([Generated_Revenue]),2) DESC
 
 -- The month of December proved to be the most lucrative, yielding approximately $4,608,295.70 in revenue. 
 -- December and October stand out as the top-performing months in revenue. Conversely, November and January are the least favorable in terms of financial performance. 

 -- 2) During the month with the highest sales, which specific day recorded the highest sales?  

 SELECT [Purchase_Day],SUM([Generated_Revenue]) AS Generated_Revenue_Per_Day
 FROM [dbo].[Combined Sales Data]
 WHERE [Purchase_Month] = 12
 GROUP BY [Purchase_Day]
 ORDER BY SUM([Generated_Revenue]) DESC

 -- The highest sales, amounting to $166,577.69, occurred on the 4th of December. 

 -- 3) Which specific day of month recorded the highest sales annually? 

  SELECT [Purchase_Day],sum([Generated_Revenue]) AS Total_Generated_Revenue
  FROM [dbo].[Combined Sales Data]
  GROUP BY [Purchase_Day]
  ORDER BY sum([Generated_Revenue]) DESC

 -- The revenue generated on the 9th of each month was notably higher, totaling $1,169,049.21, in comparison to other days. 
 -- The top two days annually, based on total revenue generated, were the 9th and 10th. Conversely, the 30th and 31st were the least favorable in terms of revenue. 
  
 -- 4) During which time of the day did people prefer to purchase products?  

 select count([Order Date]),count([Purchase_Time_Slot]) -- As we have 12467 null values in Purchase_Time_slot column.This status will change after taking below mentioned measures.
 from [dbo].[Combined Sales Data]

 -- count([Order Date])=185686 , count([Purchase_Time_Slot]) = 173219 ,Null values in Purchase_Time_Slot] = 185686 - 173219 = 12467

/*

 -- Let's find out where null values occured in Purchase_Time_Slot?

 SELECT  [Order Date],[Purchase_Time], [Purchase_Time_Slot]                   
 FROM [dbo].[Combined Sales Data]
 WHERE [Purchase_Time_Slot] IS NULL 

 -- Purchase_Time_Slot contains null value where Purchase_Time is in 'H:MM' format ( Hour is in single digit).

 -- What is the reason of null occurance?

 We calculated Purchase_Time_Slot based on following logic/query.
 
 Purchase_Time_Slot = SUBSTRING([Order Date],CHARINDEX(' ',[Order Date]) + 1,2 ) + '-' +  TRY_CONVERT(NVARCHAR(50),TRY_CAST( SUBSTRING([Order Date],CHARINDEX(' ',[Order Date]) + 1,2 ) AS INT) + 1)

 - Here we are extracting 2 characters starting from the first character after ' ' in Order Date as a Hour.
   This approch fails when Order Date contains hour value < 10 (In short when hour is in single digit) because above mentioned query will extract 'H:' in this particular case instead of 'HH".  

 -- Solution. 

  select [Order Date],DATEPART(hour,cast([Order Date] as time)) as hours,
  cast(DATEPART(hour,cast([Order Date] as time)) as varchar(50)) + '-' + cast(DATEPART(hour,cast([Order Date] as time)) + 1 as varchar(50)) as Purchase_Time_Slot -- New logic
  from [dbo].[Combined Sales Data]
  WHERE [Purchase_Time_Slot] IS NULL  

 -- Update the Purchase_Time_Slot creation logic.

  UPDATE [dbo].[Combined Sales Data]
  SET [Purchase_Time_Slot] = cast(DATEPART(hour,cast([Order Date] as time)) as varchar(50)) + '-' + cast(DATEPART(hour,cast([Order Date] as time)) + 1 as varchar(50))
  WHERE [Purchase_Time_Slot] IS NULL  

 -- As  Purchase_Time_Slot is a computed column,we can not modify it.Hence now only way is to delete this column and create new column using updated logic.

 -- Drop Purchase_Time_Slot column due to above issue.

  ALTER TABLE [dbo].[Combined Sales Data]
  DROP COLUMN [Purchase_Time_Slot]

 -- Create Purchase_Time_Slot with updated logic.

 ALTER TABLE [dbo].[Combined Sales Data]
 ADD Purchase_Time_Slot AS cast(DATEPART(hour,cast([Order Date] as time)) as varchar(50)) + '-' + cast(DATEPART(hour,cast([Order Date] as time)) + 1 as varchar(50))  

-- Let's check the status.

select count([Order Date]),count([Purchase_Time_Slot]) 
from [dbo].[Combined Sales Data]

-- Now,Purchase_Time_Slot does not have any null value in it. */
 
-- Continuing with the 4th question.

 SELECT [Purchase_Time_Slot],ROUND(SUM([Generated_Revenue]),2) AS Total_Gen_Rev_Per_Time_Slot
 FROM [dbo].[Combined Sales Data]
 GROUP BY [Purchase_Time_Slot]
 ORDER BY SUM([Generated_Revenue]) DESC

 -- In the evening, specifically between 7 and 8 PM, customers tended to place high-value orders, contributing significantly to Kmart's annual revenue. Conversely, 
 -- the time period from 2 to 6 in the morning was the least preferred for customers to place orders. 
 
 
 -- 5) Which state recorded the highest number of sales, and within that state, which city ranked at the top?  

 SELECT [State], [City],SUM([Generated_Revenue]) Total_Gen_Rev_Per_City
 FROM [dbo].[Combined Sales Data]
 GROUP BY [City],[State]
 ORDER BY SUM([Generated_Revenue]) DESC;

 /* California (CA) leads in terms of revenue generation, with San Francisco and Los Angeles topping the list, generating $8,254,743.55 and $5,448,304.28, respectively.
    On the contrary, Portland city in the state of Maine (ME) contributed the least, generating only $449,321.38 to Kmart's overall revenue growth.  */

 -- 6) What was the highest-value order placed in San Francisco, California? 

 SELECT TOP 1* 
 FROM [dbo].[Combined Sales Data]
 WHERE [City] = 'San Francisco' AND [State] = 'CA'  
 ORDER BY [Generated_Revenue] DESC

 /* The largest order in terms of revenue in San Francisco, California, was the purchase of 2 Macbook Pro Laptops.
    This order, placed on April 27, 2019, at 21:01 PM from 668 Park St, San Francisco, CA, amounted to $3,400. */

 -- 7) What was the most modest purchase made at Kmart?  

 SELECT TOP 1 *       
 FROM [dbo].[Combined Sales Data]
 WHERE [Generated_Revenue] = (SELECT MIN([Generated_Revenue]) FROM [dbo].[Combined Sales Data]);

 -- The smallest order on k-mart was of only 2.99$ for one AAA Batteries (4-pack). 
 
-- 8) What is the most affordable and the most expensive item that Kmart offered for sale? 

 SELECT TOP 1 [Product], [Price Each]
 FROM [dbo].[Combined Sales Data]
 WHERE [Price Each]= (SELECT MIN(CAST([Price Each] AS FLOAT)) FROM [dbo].[Combined Sales Data])

-- The most inexpensive item featured on Kmart's listings was a 4-pack of AAA batteries, priced at $2.99. 

 SELECT [Product],[Price Each] 
 FROM [dbo].[Combined Sales Data]
 ORDER BY CONVERT(FLOAT,[Price Each]) DESC

 -- The most expensive item offered by Kmart was the Macbook Pro Laptop, listed at a price of $1700. 

 -- 9) Which items received the most and least orders at Kmart? 
 
 SELECT [Product],COUNT([Product]) AS Number_of_Orders --OVER (PARTITION BY [Product]) AS Number_of_Orders
 FROM [dbo].[Combined Sales Data]
 GROUP BY [Product]
 ORDER BY COUNT([Product]) DESC

 -- The product with the highest number of orders on Kmart was the USB-C Charging Cable.  

 SELECT DISTINCT([Product]),COUNT([Product]) OVER (PARTITION BY [Product]) AS Number_of_Orders
 FROM [dbo].[Combined Sales Data]
 ORDER BY Number_of_Orders

 -- The least ordered products on Kmart were the LG Dryer and LG Washing Machine, with 646 and 666 orders, respectively, throughout the year 2019.

-- 10) Best time to display advertising to maximize sales?
  
-- Let's find number of orders per month.
 
 SELECT DISTINCT([Purchase_Month]),COUNT([Order ID]) OVER (PARTITION BY [Purchase_Month]) AS Orders_Per_Month
 FROM [Combined Sales Data]
 ORDER BY Orders_Per_Month 

 /*
 Typically, the optimal months for launching sales and maximizing revenue in the e-commerce sector are November, December, and January. 
 This is attributed to holiday events such as Black Friday, Cyber Monday, Boxing Day, and New Year's sales. Conversely, June, July, and August are considered slower months for online shopping
 due to the summer season.During these months, people tend to go on vacations and prefer offline shopping, leading to reduced online traffic. 
 Consequently, this period presents an opportunity for e-commerce businesses to intensify their advertising efforts, promoting various products, sales, and loyalty programs to attract customers.
 
  Based on the provided analysis, it can be inferred that January and November experienced the lowest number of orders per month, with 9699 and 11603 orders, respectively.
  This observation is contrary to expectations, as these months are typically anticipated to have peak orders due to numerous sales events.
  Consequently, it is suggested that these months present an opportune time for strategic advertising, promotional sale launches, and customer engagement efforts.
  By actively promoting products during these seemingly slower periods, there is potential to attract more customers and generate increased revenue.
 */