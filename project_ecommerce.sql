create database project_ecommerce;
use project_ecommerce;

show tables;

describe customers;
describe orders;
describe products;
describe payments;
describe shipping;
describe fact_table;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
select * from customers;
select * from orders;
select * from products;
select * from payments;
select * from shipping;
select * from fact_table;
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Assigning Primary Key
alter table customers add primary key (customer_id);
alter table orders add primary key (order_id);
alter table products add primary key (product_id);
alter table payments add primary key (payment_id);
alter table shipping add primary key (shipping_id);

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Assigning Foreign Key
alter table fact_table add constraint foreign key fkey_fact_customers(customer_id) references customers(customer_id);
alter table fact_table add constraint foreign key fkey_fact_order(order_id) references orders(order_id);
alter table fact_table add constraint foreign key fkey_fact_products(product_id) references products(product_id);
alter table fact_table add constraint foreign key fkey_fact_payments(payment_id) references payments(payment_id);
alter table fact_table add constraint foreign key fkey_fact_shipping(shipping_id) references shipping(shipping_id);

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 1 Update loyalty points for customers based on age.

select * from customers;

Update customers set loyalty_points = 
case
when age < 25 then loyalty_points + 10
when age between 25 and 40 then loyalty_points + 20
else loyalty_points + 5
end;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 2 Get total order value per country and classify sales category.

select round(sum(order_value)) from orders;
select c.country, round(sum(o.order_value),2) as total_order_value,
if(sum(o.order_value) > 100000, "High",
if (sum(o.order_value) between 50000 and 100000, "Medium", "Low")) as Sales_category
from orders o 
join customers c
on c.customer_id = o.customer_id
group by c.country;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 3 Pivot total order quantity per payment method.

select c.country, 
count(case when o.payment_method = "Credit card" then o.order_id end) as Credit_Card_qty,
count(case when o.payment_method = "Bank Transfer" then o.order_id end) as Bank_Transfer_qty,
count(case when o.payment_method = "PayPal" then o.order_id end) as PayPal_qty
from orders o
join customers c 
on c.customer_id = o.customer_id
group by country;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 4 (Joins with Subquery) Find top 3 customers by total order value and Customer_id (using Rank).

-- Using Joins and subqueries
select r.customer_id, round(r.total_order_value,2)as total_order_value, r.order_rank 
from (select customer_id,  sum(order_value) as total_order_value, rank() over(order by sum(order_value) desc) as order_rank
from orders o group by customer_id) as r 
join customers c on c.customer_id = r.customer_id where r.order_rank<=3 order by order_rank;

use project_ecommerce;

-- Using Common Table Expression CTE
with ranked_customers as ( 
select c.customer_id, round(sum(o.order_value),2) as total_order_value, rank() over(order by sum(o.order_value)desc) as order_rank 
from orders o join customers c on c.customer_id = o.customer_id
group by c.customer_id) select * from ranked_customers where order_rank<=3 order by order_rank;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 5 Find products that have been ordered more than the average quantity.

select  product_name, count(product_name) as Product_Quantity
from products group by product_name 
having  Product_Quantity > (select count(product_name)/ count(distinct product_name) from products);

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 6 Get all orders for a specific customer using customer_id

delimiter //
create procedure order_details(in customer_orders int) 
begin
select c.customer_id,c.customer_name, c.city,c.country,o.order_id, o.order_value,o.order_status, o.quantity,o.payment_method
from orders o join customers c on c.customer_id = o.customer_id where c.customer_id =customer_orders;
end //
delimiter ;
 
call order_details(4677);

drop procedure order_details;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 7 Return the total spending of a customer.

delimiter //
create procedure customer_orders(in customer_id int,  out total_spending decimal(8,2)) 
begin
select  c.customer_id,c.customer_name, o.order_id, o.order_value
from orders o join customers c on c.customer_id = o.customer_id where customer_id = o.customer_id;
select sum(o.order_value) into total_spending from orders o 
join customers c on c.customer_id = o.customer_id where customer_id = o.customer_id;
end //
delimiter ;
 
call customer_orders(45,@total_spending);
select @total_spending;

drop procedure customer_orders;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 8 Automatically set loyalty points to 0 if NULL on insert.

delimiter //
create trigger loyalty_check before insert on customers for each row
begin 
if new.loyalty_points is null then set new.loyalty_points =0;
elseif new.loyalty_points = 0 then set new.loyalty_points =0;
elseif new.loyalty_points = "" then set new.loyalty_points =0;
end if;
end //
delimiter ;

insert into customers values 
(5001, "John", "john@gmail.com", "Male", 45, "Korea", "Seoul", "2021-12-15","2025-12-15",null);

select * from customers where customer_id = 5001;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- TASK 9 After a new order is inserted, deduct quantity from product stock.

create table order_window (order_id int, customer_id int, product_id int,order_quantity int, order_date date, order_value int, order_status varchar(100));

delimiter //
create trigger inventory_change after insert on order_window for each row
begin
declare opening_stock int;
select stock_quantity into opening_stock from products where product_id = new.product_id;

if opening_stock >= new.order_quantity then 
update products set stock_quantity = stock_quantity - new.order_quantity where product_id = new.product_id;
insert into orders values (new.order_id, new.customer_id, new.product_id, new.Order_date, "Pending", new.order_quantity ,0,0,"PayPal",new.order_value);
else
insert into orders values (new.order_id, new.customer_id, new.product_id, new.Order_date, "Failed", 0 ,0,0,"Failed",0);
end if;
end //
delimiter ;

insert into products values 
(110, "Once Product","Books",	"Ward-Forbes", 405.4,500,5),
(120, "Once Product","Books",	"Ward-Forbes", 405.4,200,5);

insert into order_window values 
(5001,5001,110,200,"2025-10-08",879.22,'Placed'),
(5002,5002,120,1000,"2025-10-08",879.22,'Placed');


select * from order_window;
select * from orders where order_id in (5001,5002);
select * from products;



drop trigger inventory_change;
drop table order_window;



-- ------------------------------------------------------------------------------------------------------------------------------------------------------