--
-- PostgreSQL database cluster dump
--

-- Started on 2026-08-25 19:59:45

\restrict c2ibtv1L2sP3hBWwXBlIRnZPRXHQtJiOHwY8YfwawhTXSZjvKlAJvG0eJYxL3fy

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'SCRAM-SHA-256$4096:YLJDd6cagB4vbmfT6UjxSQ==$dYRv0rNndOdTnJWmLLfV4VWVYKoCY4ETyNCXLIK9Nu8=:9SZHGbUhpVNv1FWnOTAgqM9etW+tYcb0TUspjZq1heM=';

--
-- User Configurations
--








\unrestrict c2ibtv1L2sP3hBWwXBlIRnZPRXHQtJiOHwY8YfwawhTXSZjvKlAJvG0eJYxL3fy

-- Completed on 2026-08-25 19:59:45

--
-- PostgreSQL database cluster dump complete
--

