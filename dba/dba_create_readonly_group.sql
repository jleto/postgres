--
-- PostgreSQL database - read only group and user creation
--

-- Create a group
CREATE ROLE postgres_readonly_group;

-- Grant access to existing tables in public
GRANT USAGE ON SCHEMA public TO postgres_readonly_group;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres_readonly_group;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO postgres_readonly_group;

-- Grant access to future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO postgres_readonly_group;

-- Grant access to existing tables for schema in database
GRANT USAGE ON SCHEMA [SCHEMANAME] TO postgres_readonly_group;
GRANT SELECT ON ALL TABLES IN SCHEMA [SCHEMANAME] TO postgres_readonly_group;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA [SCHEMANAME] TO postgres_readonly_group;

-- Grant access to future tables in schema
ALTER DEFAULT PRIVILEGES IN SCHEMA [SCHEMANAME] GRANT SELECT ON TABLES TO postgres_readonly_group;

-- Create a final user with password
CREATE USER postgres_readonly WITH PASSWORD 'secret';
GRANT postgres_readonly_group TO postgres_readonly;

REVOKE CREATE ON SCHEMA public FROM public;
