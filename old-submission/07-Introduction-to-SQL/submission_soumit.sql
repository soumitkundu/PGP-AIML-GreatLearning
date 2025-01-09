/*

-----------------------------------------------------------------------------------------------------------------------------------
													    Guidelines
-----------------------------------------------------------------------------------------------------------------------------------

The provided document is a guide for the project. Follow the instructions and take the necessary steps to finish
the project in the SQL file			

-----------------------------------------------------------------------------------------------------------------------------------
                                                         Queries
                                               
-----------------------------------------------------------------------------------------------------------------------------------*/

-- First lets select the Database using USE command
USE vehdb;

/*QUESTIONS RELATED TO CUSTOMERS
     [Q1] What is the distribution of customers across states?
     Hint: For each state, count the number of customers.*/
     
SELECT state, COUNT(customer_id) AS no_of_customers 
FROM customer_t 
GROUP BY state 
ORDER BY no_of_customers DESC;
-- Most customers are from California, Texas, Florida, and New York

---------------------------------------------------------------------------------------------------------------------------------

/* [Q2] What is the average rating in each quarter?
-- Very Bad is 1, Bad is 2, Okay is 3, Good is 4, Very Good is 5.

Hint: Use a common table expression and in that CTE, assign numbers to the different customer ratings. 
      Now average the feedback for each quarter. */

-- Lets check the maximum and minimum order date so that we can understand if the quarter is distributed in different years or not
SELECT MAX(order_date) AS max_order_date, MIN(order_date) AS min_order_date 
FROM order_t;
-- Okay all the orders are made in the year 2018 only

-- Using case when clause lets convert the customer feedback text to numeric rating
-- Later it can be used as sub query
SELECT order_id, customer_id, shipper_id, quarter_number, customer_feedback, 
	CASE
		WHEN customer_feedback = 'Very Bad' THEN 1
		WHEN customer_feedback = 'Bad' THEN 2
		WHEN customer_feedback = 'Okay' THEN 3
		WHEN customer_feedback = 'Good' THEN 4
		WHEN customer_feedback = 'Very Good' THEN 5
		ELSE customer_feedback
	END AS customer_rating
FROM order_t;

-- Now using the above query as sub query lets get the average rating based on different quarters
WITH CTE_customer_rating 
AS (
	SELECT quarter_number, customer_feedback, 
		CASE
			WHEN customer_feedback = 'Very Bad' THEN 1
			WHEN customer_feedback = 'Bad' THEN 2
			WHEN customer_feedback = 'Okay' THEN 3
			WHEN customer_feedback = 'Good' THEN 4
			WHEN customer_feedback = 'Very Good' THEN 5
			ELSE customer_feedback
		END AS customer_rating
	FROM order_t
)
SELECT quarter_number, AVG(customer_rating) AS average_rating 
FROM CTE_customer_rating
GROUP BY quarter_number
ORDER BY quarter_number;
-- We can see there is a significant fall in customer rating

---------------------------------------------------------------------------------------------------------------------------------

/* [Q3] Are customers getting more dissatisfied over time?

Hint: Need the percentage of different types of customer feedback in each quarter. Use a common table expression and
	  determine the number of customer feedback in each category as well as the total number of customer feedback in each quarter.
	  Now use that common table expression to find out the percentage of different types of customer feedback in each quarter.
      Eg: (total number of very good feedback/total customer feedback)* 100 gives you the percentage of very good feedback.*/
      
-- Lets count total customer feedback for each quarter
SELECT quarter_number, COUNT(customer_feedback) AS total_feedback
FROM order_t
GROUP BY quarter_number;
-- Okay we can use the above query as a subquery for percentage calculation

-- Now lets count different types of feedback for each quarter
SELECT customer_feedback, quarter_number, COUNT(customer_feedback) AS feedback_count
FROM order_t
GROUP BY quarter_number, customer_feedback;

-- Now lets use both the queries to calculate percentage of different types of feedback for each quarter
WITH CTE_customer_feedback_cnt
AS (
	SELECT quarter_number, COUNT(customer_feedback) AS total_feedback
    FROM order_t
    GROUP BY quarter_number
), 
CTE_quarterly_feedback_cnt
AS (
	SELECT customer_feedback, quarter_number, COUNT(customer_feedback) AS feedback_count
	FROM order_t
	GROUP BY quarter_number, customer_feedback
)
SELECT customer_feedback, cf.quarter_number, (feedback_count / total_feedback) * 100 AS feedback_percentage
FROM CTE_customer_feedback_cnt cf 
INNER JOIN CTE_quarterly_feedback_cnt qf ON cf.quarter_number = qf.quarter_number 
-- customizing the order by using field function on customer_feedback column
ORDER BY FIELD(customer_feedback, 'Very Bad', 'Bad', 'Okay', 'Good', 'Very Good'), cf.quarter_number;
-- We can see there is a significant hike in Bad and Very Bad feedback over time also drastical fall in Good and Very Good feedback.
-- So its clear that the customers getting more dissatisfied over time

---------------------------------------------------------------------------------------------------------------------------------

/*[Q4] Which are the top 5 vehicle makers preferred by the customer.

Hint: For each vehicle make what is the count of the customers.*/

-- Lets count the number of customers for each vehicle maker
-- ordering the result with number of customers high to low and limit to 5 will fetch only top 5 rows
SELECT P.vehicle_maker, COUNT(O.customer_id) AS no_of_customers 
FROM order_t O
INNER JOIN product_t P ON O.product_id = P.product_id
GROUP BY P.vehicle_maker
ORDER BY COUNT(O.customer_id) DESC
LIMIT 5;

-- Also lets check what is the total number of quantity ordered for each vehicle maker
SELECT P.vehicle_maker, SUM(O.quantity) AS ordered_quantity 
FROM order_t O
INNER JOIN product_t P ON O.product_id = P.product_id
GROUP BY P.vehicle_maker
ORDER BY SUM(O.quantity) DESC
LIMIT 5;
-- In both case Chevrolet, Ford, Toyota, Pontiac and Dodge respectively are the top 5 vehicle makers preferred by the customer

---------------------------------------------------------------------------------------------------------------------------------

/*[Q5] What is the most preferred vehicle make in each state?

Hint: Use the window function RANK() to rank based on the count of customers for each state and vehicle maker. 
After ranking, take the vehicle maker whose rank is 1.*/

-- Lets count the number of customer for each state and each vehicle maker and also with rank
SELECT P.vehicle_maker, C.state, COUNT(O.customer_id) AS no_of_customer, 
	RANK() OVER (
		PARTITION BY C.state ORDER BY COUNT(O.customer_id) DESC
	) AS preferred_rank
FROM order_t O
INNER JOIN product_t P ON O.product_id = P.product_id
INNER JOIN customer_t C ON O.customer_id = C.customer_id
GROUP BY 1, 2
ORDER BY no_of_customer DESC;
-- Now we can use the above query as a sub query to fetch those records where rank is 1
WITH CTE_preferred_vehicle_maker
AS (
	SELECT P.vehicle_maker, C.state, COUNT(O.customer_id) AS no_of_customer, 
		RANK() OVER (
			PARTITION BY C.state ORDER BY COUNT(O.customer_id) DESC
		) AS preferred_rank
	FROM order_t O
	INNER JOIN product_t P ON O.product_id = P.product_id
	INNER JOIN customer_t C ON O.customer_id = C.customer_id
	GROUP BY 1, 2
)
SELECT state, vehicle_maker 
FROM CTE_preferred_vehicle_maker
WHERE preferred_rank = 1
ORDER BY 1, 2;


-- ---------------------------------------------------------------------------------------------------------------------------------

/*QUESTIONS RELATED TO REVENUE and ORDERS 

-- [Q6] What is the trend of number of orders by quarters?

Hint: Count the number of orders for each quarter.*/

SELECT quarter_number, COUNT(order_id) AS no_of_order
FROM order_t 
GROUP BY quarter_number
ORDER BY quarter_number ASC;
-- Number of orders falling down over time in each quarter we can see.

---------------------------------------------------------------------------------------------------------------------------------

/* [Q7] What is the quarter over quarter % change in revenue? 

Hint: Quarter over Quarter percentage change in revenue means what is the change in revenue from the subsequent quarter to the previous quarter in percentage.
      To calculate you need to use the common table expression to find out the sum of revenue for each quarter.
      Then use that CTE along with the LAG function to calculate the QoQ percentage change in revenue.
*/
      
-- Lets calculate the total revenue earned in each quarter
SELECT quarter_number,
	  SUM((vehicle_price - ((discount / 100) * vehicle_price))) AS total_revenue
FROM order_t
GROUP BY 1
ORDER BY 1;
-- Now using the above query with LAG function we can calaulate the percentage change in revenue with current and previous qtr revenue
WITH CTE_QoQ 
AS (
    SELECT quarter_number,
          SUM((vehicle_price - ((discount / 100) * vehicle_price))) AS total_revenue
    FROM order_t
	GROUP BY 1
)
SELECT quarter_number, total_revenue,
      LAG(total_revenue) OVER(ORDER BY quarter_number) AS previous_revenue,
      (total_revenue - LAG(total_revenue) OVER(ORDER BY quarter_number)) / LAG(total_revenue) OVER(ORDER BY quarter_number) AS qoq_perc_change
FROM CTE_QoQ;
-- ---------------------------------------------------------------------------------------------------------------------------------

/* [Q8] What is the trend of revenue and orders by quarters?

Hint: Find out the sum of revenue and count the number of orders for each quarter.*/

SELECT quarter_number, 
	SUM((vehicle_price - ((discount / 100) * vehicle_price))) AS total_revenue, 
    COUNT(order_id) AS no_of_order 
FROM order_t 
GROUP BY quarter_number
ORDER BY quarter_number ASC;
-- There is a huge fall in revenue and orders in each quarter.

---------------------------------------------------------------------------------------------------------------------------------

/* QUESTIONS RELATED TO SHIPPING 
    [Q9] What is the average discount offered for different types of credit cards?

Hint: Find out the average of discount for each credit card type.*/

SELECT C.credit_card_type, AVG(O.discount) AS average_discount
FROM order_t O
INNER JOIN customer_t C ON O.customer_id = C.customer_id
GROUP BY C.credit_card_type
ORDER BY AVG(O.discount) DESC;
-- There is not a big difference in discount for each credit card type, however among those laser cards offers highest discount.

---------------------------------------------------------------------------------------------------------------------------------

/* [Q10] What is the average time taken to ship the placed orders for each quarters?
	Hint: Use the dateiff function to find the difference between the ship date and the order date.
*/

SELECT quarter_number, 
ROUND(AVG(DATEDIFF(ship_date, order_date)), 2) AS average_shipping_time
FROM order_t
GROUP BY quarter_number
ORDER BY quarter_number;
-- Here we can see the average shipping time taken by the company is significantly going high over time.
-- So it is very natural that the customers will be frustrated and give bad feedback. 
-- Company should take necessary action on this matter very seriously to perform well in the future.
-- --------------------------------------------------------Done----------------------------------------------------------------------
-- ----------------------------------------------------------------------------------------------------------------------------------



