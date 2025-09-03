SHOW DATABASES;
USE my_new_db;
SHOW TABLES;
SELECT database();
DROP DATABASE IF EXISTS my_new_db;
CREATE DATABASE IF NOT EXISTS my_new_db;
USE my_new_db;

CREATE TABLE IF NOT EXISTS my_simple_table (
    country VARCHAR(2) NOT NULL,
    name VARCHAR(15) NOT NULL,
    description VARCHAR(255),
    CONSTRAINT pk_my_simple_table 
        PRIMARY KEY (country, name)
);

CREATE TABLE IF NOT EXISTS my_table (
    id VARCHAR(36) DEFAULT (UUID()),
    country VARCHAR(2) DEFAULT 'US'
        CONSTRAINT chk_country 
        CHECK (country IN ('US', 'CA', 'MX', 'UK')),
    name VARCHAR(15),
    cap_name VARCHAR(15),
    CONSTRAINT pk_my_table
        PRIMARY KEY (id),
    CONSTRAINT fk1
        FOREIGN KEY (country, name)
        REFERENCES my_simple_table(country, name),
    CONSTRAINT unq_country_name
        UNIQUE (country, name),
    CONSTRAINT chk_upper_name
        CHECK (cap_name = UPPER(name))
);

INSERT INTO my_simple_table (country, name, description) VALUES
('UK', 'London', 'Capital of England'),
('UK', 'Manchester', 'Famous for its music scene'),
('UK', 'Birmingham', 'Known for its industrial history'),
('UK', 'Leeds', 'West Yorkshire city'),
('UK', 'Glasgow', 'Largest city in Scotland'),
('UK', 'Liverpool', 'Famous for The Beatles'),
('UK', 'Sheffield', 'Known for its steel industry'),
('UK', 'Bristol', 'City in South West England'),
('UK', 'Newcastle', 'Famous for its nightlife'),
('UK', 'Nottingham', 'Home of Robin Hood'),
('US', 'New York City', 'The Big Apple'),
('US', 'San Francisco', 'Known for the Golden Gate Bridge'),
('US', 'Boston', 'Home of Harvard University'),
('US', 'New York', 'The Big Apple'),
('US', 'Chicago', 'Known for its architecture'),
('US', 'Los Angeles', 'City of Angels'),
('CA', 'Toronto', 'Largest city in Canada'),
('CA', 'Montreal', 'Known for its French heritage'),
('CA', 'Calgary', 'Known for the Calgary Stampede'),
('CA', 'Ottawa', 'Capital city of Canada'),
('CA', 'Edmonton', 'Known for its mall'),
('CA', 'Quebec City', 'Known for its historic architecture'),
('CA', 'Halifax', 'Known for its maritime history'),
('CA', 'Victoria', 'Known for its gardens'),
('CA', 'Winnipeg', 'Known for its cultural diversity'),
('CA', 'Saskatoon', 'Known for its riverbank'),
('CA', 'Regina', 'Known for its legislative building'),
('CA', 'St. Johns', 'Known for its colorful row houses'),
('CA', 'Kitchener', 'Known for its Oktoberfest'),
('CA', 'Vancouver', 'Known for its natural beauty'),
('MX', 'Mexico City', 'The capital of Mexico'),
('MX', 'Guadalajara', 'Known for its mariachi music'),
('MX', 'Monterrey', 'Known for its industrial output'),
('MX', 'Cancun', 'Famous for its beaches'),
('MX', 'Tijuana', 'Known for its border culture'),
('MX', 'Puebla', 'Known for its culinary history');

INSERT INTO my_table (country, name, cap_name) VALUES
('UK', 'London', 'LONDON'),
('US', 'New York City', 'NEW YORK CITY'),
('CA', 'Toronto', 'TORONTO'),
('MX', 'Mexico City', 'MEXICO CITY');

DROP DATABASE IF EXISTS my_new_db;
DROP TABLE IF EXISTS my_simple_table;
DROP TABLE IF EXISTS my_table;
DROP TABLE IF EXISTS my_orders;

----------------------------------
CREATE DATABASE IF NOT EXISTS shop_db;
USE shop_db;
SHOW TABLES;

CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(36) DEFAULT (UUID()),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id VARCHAR(36) DEFAULT (UUID()),
    name VARCHAR(100) NOT NULL,
    contact_name VARCHAR(100),
    phone VARCHAR(15),
    email VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_suppliers PRIMARY KEY (supplier_id)
);

CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(36) DEFAULT (UUID()),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock INT NOT NULL CHECK (stock >= 0),
    CONSTRAINT pk_products PRIMARY KEY (product_id)
);

CREATE TABLE IF NOT EXISTS products_suppliers (
    product_id VARCHAR(36),
    supplier_id VARCHAR(36),
    CONSTRAINT pk_products_suppliers PRIMARY KEY (product_id, supplier_id),
    CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_suppliers FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE IF NOT EXISTS orders_status (
    status_id INT AUTO_INCREMENT,
    status_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    CONSTRAINT pk_orders_status PRIMARY KEY (status_id)
);

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(36) DEFAULT (UUID()),
    customer_id VARCHAR(36),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status_id INT DEFAULT 1,
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_status FOREIGN KEY (status_id) REFERENCES orders_status(status_id)
);

----------------------------------
-- INSERT OPERATIONS
-----------------------------------

INSERT INTO customers (name, email) VALUES
('Alice Johnson', 'alice.johnson@example.com'),
('Bob Smith', 'bob.smith@example.com'),
('Charlie Brown', 'charlie.brown@example.com'),
('Diana Prince', 'diana.prince@example.com'),
('Ethan Hunt', 'ethan.hunt@example.com'),
('Fiona Gallagher', 'fiona.gallagher@example.com'),
('George Costanza', 'george.costanza@example.com'),
('Hannah Baker', 'hannah.baker@example.com'),
('Ian Malcolm', 'ian.malcolm@example.com'),
('Jane Doe', 'jane.doe@example.com');

INSERT INTO suppliers (name, contact_name, phone, email) VALUES
('Tech Supplies Co.', 'John Doe', '123-456-7890', 'john.doe@techsupplies.com'),
('Office Supplies Inc.', 'Jane Smith', '987-654-3210', 'jane.smith@officesupplies.com'),
('Electronics Wholesalers', 'Jim Brown', '555-123-4567', 'jim.brown@electronicswholesalers.com'),
('Furniture World', 'Sara White', '444-555-6666', 'sara.white@furnitureworld.com'),
('Gadget Central', 'Tom Green', '333-444-5555', 'tom.green@gadgetcentral.com'),
('Stationery Hub', 'Lucy Blue', '222-333-4444', 'lucy.blue@stationeryhub.com'),
('TechnoMart', 'Mike Black', '111-222-3333', 'mike.black@technomart.com');

INSERT INTO products (name, description, price, stock) VALUES
('Laptop', 'High performance laptop', 999.99, 50),
('Smartphone', 'Latest model smartphone', 699.99, 100),
('Tablet', '10-inch tablet device', 399.99, 75),
('Monitor', '24-inch HD monitor', 199.99, 60),
('Keyboard', 'Mechanical keyboard', 89.99, 150),
('Mouse', 'Wireless mouse', 49.99, 200),
('Printer', 'All-in-one printer', 149.99, 40),
('Desk Chair', 'Ergonomic office chair', 129.99, 30),
('USB Drive', '64GB USB flash drive', 19.99, 300),
('External Hard Drive', '1TB external hard drive', 79.99, 80),
('Webcam', 'HD webcam for video conferencing', 59.99, 90),
('Headphones', 'Noise-cancelling headphones', 149.99, 70),
('Speakers', 'Bluetooth speakers', 89.99, 110),
('Router', 'Wireless router', 129.99, 55),
('Projector', '1080p projector', 499.99, 25),
('Scanner', 'High-resolution scanner', 199.99, 35),
('Microphone', 'USB condenser microphone', 99.99, 45),
('Graphics Tablet', 'Digital drawing tablet', 249.99, 20),
('Smartwatch', 'Fitness tracking smartwatch', 199.99, 85),
('VR Headset', 'Virtual reality headset', 399.99, 15);

INSERT INTO products_suppliers (product_id, supplier_id) VALUES
((SELECT product_id FROM products WHERE name = 'Laptop'), (SELECT supplier_id FROM suppliers WHERE name = 'Tech Supplies Co.')),
((SELECT product_id FROM products WHERE name = 'Smartphone'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers')),
((SELECT product_id FROM products WHERE name = 'Tablet'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers')),
((SELECT product_id FROM products WHERE name = 'Monitor'), (SELECT supplier_id FROM suppliers WHERE name = 'Tech Supplies Co.')),
((SELECT product_id FROM products WHERE name = 'Keyboard'), (SELECT supplier_id FROM suppliers WHERE name = 'Office Supplies Inc.')),
((SELECT product_id FROM products WHERE name = 'Mouse'), (SELECT supplier_id FROM suppliers WHERE name = 'Office Supplies Inc.')),
((SELECT product_id FROM products WHERE name = 'Printer'), (SELECT supplier_id FROM suppliers WHERE name = 'Tech Supplies Co.')),
((SELECT product_id FROM products WHERE name = 'Desk Chair'), (SELECT supplier_id FROM suppliers WHERE name = 'Furniture World')),
((SELECT product_id FROM products WHERE name = 'USB Drive'), (SELECT supplier_id FROM suppliers WHERE name = 'Gadget Central')),
((SELECT product_id FROM products WHERE name = 'External Hard Drive'), (SELECT supplier_id FROM suppliers WHERE name = 'Gadget Central')),
((SELECT product_id FROM products WHERE name = 'Webcam'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers')),
((SELECT product_id FROM products WHERE name = 'Headphones'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers')),
((SELECT product_id FROM products WHERE name = 'Speakers'), (SELECT supplier_id FROM suppliers WHERE name = 'Gadget Central')),
((SELECT product_id FROM products WHERE name = 'Router'), (SELECT supplier_id FROM suppliers WHERE name = 'TechnoMart')),
((SELECT product_id FROM products WHERE name = 'Projector'), (SELECT supplier_id FROM suppliers WHERE name = 'Tech Supplies Co.')),
((SELECT product_id FROM products WHERE name = 'Scanner'), (SELECT supplier_id FROM suppliers WHERE name = 'Tech Supplies Co.')),
((SELECT product_id FROM products WHERE name = 'Microphone'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers')),
((SELECT product_id FROM products WHERE name = 'Graphics Tablet'), (SELECT supplier_id FROM suppliers WHERE name = 'Gadget Central')),
((SELECT product_id FROM products WHERE name = 'Smartwatch'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers')),
((SELECT product_id FROM products WHERE name = 'VR Headset'), (SELECT supplier_id FROM suppliers WHERE name = 'Electronics Wholesalers'));

INSERT INTO orders_status (status_name, description) VALUES
('Pending', 'Order has been placed but not yet processed'),
('Processing', 'Order is being processed'),
('Shipped', 'Order has been shipped'),
('Delivered', 'Order has been delivered to the customer'),
('Cancelled', 'Order has been cancelled'),
('Returned', 'Order has been returned by the customer'),
('Refunded', 'Order has been refunded to the customer');
