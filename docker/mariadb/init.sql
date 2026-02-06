-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS `my_project`;
-- Create application user
CREATE USER IF NOT EXISTS 'laravel'@'%' IDENTIFIED BY 'secret';
-- Grant privileges
GRANT ALL PRIVILEGES ON `my_project`.* TO 'laravel'@'%';
FLUSH PRIVILEGES;