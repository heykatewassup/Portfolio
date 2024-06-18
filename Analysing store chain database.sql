---Question: How much money does each customer spend on average at each store?

WITH customer_counts AS (
    SELECT c.state, 
           COUNT(DISTINCT c.customer_id) AS num_customers
    FROM customers c
    JOIN project.orders o ON c.customer_id = o.customer_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2018
    GROUP BY c.state
),
total_spending_per_customer AS (
    SELECT 
        c.state,
        SUM(oi.quantity * oi.list_price) / cc.num_customers AS spending_per_customer
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customer_counts cc ON c.state = cc.state
    WHERE EXTRACT(YEAR FROM o.order_date) = 2018
    GROUP BY c.state, cc.num_customers
),
top_states AS (
    SELECT 
        state, 
        spending_per_customer,
        RANK() OVER (ORDER BY spending_per_customer DESC) AS state_rank
    FROM total_spending_per_customer
    WHERE state IS NOT NULL
)
SELECT state,
       spending_per_customer,
       state_rank
FROM top_states
ORDER BY state_rank;

---Customers from which state have made the most orders for the whole time?

select c.state, count (o.order_id) as n_orders_by_state
from customers c 
inner join orders o on c.customer_id = o.customer_id 
group by c.state
order by count(order_id) desc;

---СCustomers from which state have made the most orders for the last available in data year(2018)?

select date_part('YEAR',o.order_date) as year, c.state, count (o.order_id) as n_orders_by_state
from customers c 
inner join orders o on c.customer_id = o.customer_id 
where  date_part('YEAR',order_date) = '2018'
group by c.state, date_part('YEAR',o.order_date)
order by count(order_id) desc;

---Which are top-10 cities where customers have made the most orders?

select c.city, c.state, count(o.order_id) as n_orders_by_city
from customers c 
inner join orders o on c.customer_id = o.customer_id 
group by c.city,c.state 
order by count(order_id) desc
limit 10;

-- In what cities people mostly leave their phone numbers?

select city, count(c.city) as phone_numbers_left,
row_number()over(order by -count(c.city))
from customers c
where c.phone notnull
group by c.city
order by count(c.city) desc
limit 10;

select city, count(c.city) as phone_numbers_left,
row_number()over(order by -count(c.city))
from customers c
where c.phone notnull
group by c.city
order by count(c.city) asc
limit 10;

--Question: In which month are items sold the most for the whole time?

SELECT EXTRACT(MONTH FROM order_date) AS month, 
       SUM(quantity * list_price) AS total_sales
FROM project.orders
JOIN project.order_items ON orders.order_id = order_items.order_id
GROUP BY EXTRACT(MONTH FROM orders.order_date)
ORDER BY month;

-- What brands are leading in terms of total revenue?

select
b.brand_name as brand_name,
sum(oi.list_price * oi.quantity) as total_revenue,
row_number()over(order by -sum(oi.list_price * oi.quantity)) as top
from brands b
join products p using (brand_id)
join order_items oi using (product_id)
group by b.brand_name;

-- Which cities mainly buy the top-3 brands (by sales)? 
select
c.city as city,
b.brand_name as brand_name,
sum(oi.list_price * oi.quantity) as total_revenue_by_city,
dense_rank() over(order by -sum(oi.list_price * oi.quantity)) as top
from brands b
join products p using (brand_id)
join order_items oi using (product_id)
join orders o using (order_id)
join customers c using (customer_id)
group by b.brand_name, c.city
order by total_revenue_by_city desc
limit 10;

---Inside of each category, what is the average difference between the product price and the average product price inside the category?

select category_name, round(avg(product_price),2) as avg_cat_price, round(avg(price_diff),2) as avg_price_dev
from (select c.category_name, p.list_price as product_price, abs(p.list_price - avg(p.list_price) over (partition by p.category_id)) as price_diff
    from products p
    inner join categories c ON p.category_id = c.category_id) AS calculations
group by category_name
order by round(avg(product_price),2) desc;

-- What is the average discount and total quantity of sold products in each category?

select c.category_name,
concat(round(avg(oi.discount*100), 2), ' %') as average_discount,
sum(oi.quantity) as total_quantity
from categories c
join products p using (category_id)
join order_items oi using (product_id)
group by c.category_name
order by average_discount desc;

---How effective are discounts in driving sales in different categories of products?

select*,
round(total_quantity_sold*1.0/number_of_sales,3) as share_of_bikes_by_order
from(select c.category_name, round(avg(oi.list_price),2) as avg_cat_price,  round(avg(oi.discount) * 100, 2) || '%' as av_cat_discount,count(oi.order_id) as number_of_sales,sum(oi.quantity) as total_quantity_sold
from order_items oi
inner join products p on oi.product_id = p.product_id
inner join categories c on p.category_id =c.category_id 
group by c.category_name
order by sum(oi.quantity) desc) as table1;

-- Which categories in which store generate the most revenue?

select *, revenue_per_shop -  average_revenue_per_shop as diff
from(
select *, round(avg(revenue_per_shop) over(order by store_name),2) as average_revenue_per_shop
from(
select store_name, category_name, 
round(sum((quantity*order_items.list_price)-(quantity*order_items.list_price*discount)),1) as revenue_per_shop
 from stores 
 inner join orders using(store_id)
 inner join order_items using(order_id) 
 inner join products using (product_id)
 inner join categories using (category_id)
 group by store_name, category_name 
) as table1 
) as table2
order by diff desc;

--Question: How much money did each store bring in total in 2018? (How much money did customers spend at each store in 2018?)

SELECT 
    c.state,
    SUM(oi.quantity * oi.list_price) AS total_spending
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE EXTRACT(YEAR FROM o.order_date) = 2018
GROUP BY c.state
ORDER BY total_spending DESC;

--Question: Which employee is the most effective and brings the most value to the company in each store and among all ones in 2018? 

--which employee sold the biggest number of items
WITH ranked_staff AS (
    SELECT
        s.staff_id,
        CONCAT(s.first_name, ' ', s.last_name) AS full_name,
        SUM(oi.quantity) AS total_sold_items,
        c.state,
        ROW_NUMBER() OVER(PARTITION BY c.state ORDER BY SUM(oi.quantity) DESC) AS row_num
    FROM Staff s
    JOIN Orders o ON s.staff_id = o.staff_id
    JOIN Order_Items oi ON o.order_id = oi.order_id
    JOIN Customers c ON o.customer_id = c.customer_id
    WHERE DATE_PART('YEAR', o.order_date) = 2018
    GROUP BY s.staff_id, full_name, c.state
)
SELECT
    staff_id,
    full_name,
    total_sold_items,
    state
FROM ranked_staff
WHERE row_num = 1
ORDER BY total_sold_items DESC;

--which employee`s customers spend more money in each store

WITH ranked_staff AS (
    SELECT
        s.staff_id,
        CONCAT(s.first_name, ' ', s.last_name) AS full_name,
        SUM(oi.quantity * oi.list_price) AS total_customer_spending,
        c.state,
        s.store_id,
        ROW_NUMBER() OVER(PARTITION BY s.store_id ORDER BY SUM(oi.quantity * oi.list_price) DESC) AS row_num
    FROM staff s
    JOIN orders o ON s.staff_id = o.staff_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE EXTRACT(YEAR FROM o.order_date) = 2018
    GROUP BY s.staff_id, full_name, c.state, s.store_id
)
SELECT
    staff_id,
    full_name,
    total_customer_spending,
    state
FROM ranked_staff
WHERE row_num = 1
ORDER BY total_customer_spending DESC;

--proves that there is only 1 store in each state 
SELECT COUNT(*) AS num_stores_in_ny
FROM stores
WHERE state = 'NY';
SELECT COUNT(*) AS num_stores_in_ca
FROM stores
WHERE state = 'CA';
SELECT COUNT(*) AS num_stores_in_tx
FROM stores
WHERE state = 'TX';

-- Which employee carries out the order from order_date to shipped_date the fastest?

select concat(first_name,' ', last_name) as employee_name,
round(avg(shipped_date - order_date),2) as average_time_from_registration_to_shipment_of_the_order,
row_number() over(order by - round(avg(shipped_date - order_date),2))
from orders 
inner join staff using(staff_id)
group by concat(first_name,' ', last_name)
order by average_time_from_registration_to_shipment_of_the_order desc;
;

-- Which employee makes the highest average check? 
select concat(first_name,' ', last_name) as employee_name, 
to_char(cast(round(avg((quantity*order_items.list_price)-(quantity*order_items.list_price*discount)),1) as decimal), 'L9G999D9') as average_check
from order_items 
inner join orders using(order_id)
inner join staff using(staff_id)
group by concat(first_name,' ', last_name)
order by average_check desc;
