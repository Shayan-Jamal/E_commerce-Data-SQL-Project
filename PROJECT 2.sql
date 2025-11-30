CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    name TEXT,
    gender TEXT,
    city TEXT,
    signup_date DATE
);
drop table customers;
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    category TEXT,
    sub_category TEXT,
    price NUMERIC,
    launch_date DATE
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT REFERENCES customers(customer_id),
    order_date DATE,
    payment_mode TEXT,
    total_amount NUMERIC
);

CREATE TABLE order_items (
    order_id TEXT REFERENCES orders(order_id),
    product_id TEXT REFERENCES products(product_id),
    quantity INTEGER,
    discount_percent INTEGER,
    unit_price NUMERIC,
    line_total NUMERIC
);

CREATE TABLE reviews (
    review_id TEXT PRIMARY KEY,
    order_id TEXT REFERENCES orders(order_id),
    rating INTEGER,
    review_text TEXT,
    review_date DATE
);
select * from customers;
select * from products;
select * from orders;
select * from order_items;
select * from reviews;

---Top 10 customers by total spent, total orders,total amount,and average order value.
SELECT
	C.NAME,
	C.CUSTOMER_ID,
	SUM(O.TOTAL_AMOUNT) AS TOTAL_AMOUNT,
	COUNT(OT.QUANTITY) AS TOTAL_ORDER_PLACED,
	AVG(TOTAL_AMOUNT) AS AVERAGE_ORDER_VALUE
FROM
	CUSTOMERS C
	JOIN ORDERS O ON C.CUSTOMER_ID = O.CUSTOMER_ID
	JOIN ORDER_ITEMS OT ON O.ORDER_ID = OT.ORDER_ID
GROUP BY
	C.NAME,
	C.CUSTOMER_ID
ORDER BY
	TOTAL_AMOUNT DESC;
--identifying loyal customer:customer who made purchase in atleast 3 diff. months
select customer_id, count(distinct date_trunc('month',order_date)) as diff_month_orders
from orders
group by customer_id
having count(distinct date_trunc('month',order_date))>=3;

--calculaing the revenue contribution of each city and rank acc. to contribution
select * from (select c.city,sum(o.total_amount) as total_revenue,
rank() over (order by sum(o.total_amount) desc) as rnk
from customers c
join orders o on o.customer_id=c.customer_id
group by c.city ) t
order by total_revenue desc;

--find customers who spend above average order value but never used COD--
select * from (select c.name, o.payment_mode as payment_mde, 
sum(o.total_amount) as total_amnt,
avg(o.total_amount) as average_amnt
from customers c
join orders o on o.customer_id=c.customer_id
group by c.name,o.payment_mode) n
where total_amnt>average_amnt and payment_mde!='COD';

--PRODUCT CATEGORY ANALYSIS
--list top 5 products in terms of total quantity sold along with reveue generated--
select ot.product_id, sum(ot.quantity) as total_quantity, 
sum(o.total_amount) as total_revenue
from orders o
join order_items ot on ot.order_id=o.order_id
group by ot.product_id order by total_revenue desc, total_quantity desc 
limit 5;

--for each category, find the product with the highest discount given--
select * from (select p.product_id, p.category, ot.discount_percent,
row_number() over (partition by p.category order by ot.discount_percent desc) as rank_
from products p
join order_items ot on ot.product_id=p.product_id)
where rank_=1;

-- identify products withg average rating<overall average rating
select * from (select p.product_id, avg(r.rating) as avg_rating,sum(r.rating) as rating
from products p
join order_items ot on p.product_id=ot.product_id
join reviews r on r.order_id=ot.order_id
group by p.product_id) g
where avg_rating<g.rating;
--
--find the category with highest repeat purchase rate(customer buying same product more
--than once
select p.category,count(ot.quantity) as orders_placed
from order_items ot
join products p on p.product_id=ot.product_id
group by p.category
order by orders_placed desc
limit 1;

--ORDER & PAYMENT ANALYSIS
--calculate the month_on_month revenue growth using a window function.
select date_trunc('month',order_date) as month, sum(total_amount) as total_revenue
from orders
group by month
order by month;

--find the payment mode contribution the most revenue per quarter
select date_trunc('quarter',order_date) as quarter,payment_mode,
sum(total_amount) as total_revenue
from orders
group by quarter,payment_mode order by total_revenue desc,quarter asc;

--identify order with the highest discount and compute their total revenue impact
select o.order_id,sum(ot.discount_percent) as total_discount,
sum(o.total_amount) as total_revenue
from orders o
join order_items ot on o.order_id=ot.order_id
group by o.order_id order by total_discount desc
limit 1;

--find orders containing multiple items from different categories.
select ot.order_id
	   from order_items ot
	   join products p on ot.product_id=p.product_id
	   group by ot.order_id
	   having count(distinct p.category)>1;
	   
--REVIEWS & RATINGS--

--find the top 5 highest-rated products(minimum 10 reviews).
select p.product_id,count(review_id) as total_reviews,
avg(r.rating) as avg_rating
from order_items ot
join products p on  p.product_id=ot.product_id
join reviews r on ot.order_id=r.order_id
group by p.product_id
having count(review_id)>=10
order by avg_rating desc
limit 5;

--identify customers who gave 5_star reviews but ordered only once
select *,row_number() over(partition by rtng order by total_orders desc) as row_num
from(select o.customer_id,count(o.order_date) as total_orders, r.rating as rtng
from orders o
join reviews r on r.order_id=o.order_id
group by  o.customer_id,r.rating)
where total_orders=1 and rtng=5;

--compute average rating per category and rank categories.
select *,
rank() over(order by avg_rating desc)
from
(select p.category, avg(r.rating) as avg_rating
from products p
join order_items ot on ot.product_id=p.product_id
join reviews r on ot.order_id=r.order_id
group by p.category);

--find products where ratings decreased over time(trend analysis)
select *
from (
    select p.product_id,r.rating, r.review_date,
	lag(rating) over(partition by p.product_id order by r.review_date) as prev_rating
	from products p
    join order_items ot
	on ot.product_id=p.product_id
    join reviews r
	on ot.order_id=r.order_id
	)
	where prev_rating>rating;
