--
-- PostgreSQL database cluster dump
--

-- Started on 2026-08-31 19:24:31

\restrict KOi5kNBwLxOfJwCGJARX3f3yd6nSPcL6uTbD75uGlQD345yR8BmUNxZgqI0nZbU

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








\unrestrict KOi5kNBwLxOfJwCGJARX3f3yd6nSPcL6uTbD75uGlQD345yR8BmUNxZgqI0nZbU

--
-- Databases
--

--
-- Database "template1" dump
--

\connect template1

--
-- PostgreSQL database dump
--

\restrict BPFdGSVYp0PAtJE88eQegrct7iOaNXVGPFVyLLQBah5twB0NLNKhng80oWORJsC

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-08-31 19:24:31

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Completed on 2026-08-31 19:24:31

--
-- PostgreSQL database dump complete
--

\unrestrict BPFdGSVYp0PAtJE88eQegrct7iOaNXVGPFVyLLQBah5twB0NLNKhng80oWORJsC

--
-- Database "postgres" dump
--

\connect postgres

--
-- PostgreSQL database dump
--

\restrict ezGtdETa5yIu6PbsAy25KUOkqiMNeuuCFIZ9Ipn9XasbueSGxHigh5lYWlDtjfQ

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-08-31 19:24:31

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 3 (class 3079 OID 16711)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 5463 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 2 (class 3079 OID 16673)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 5464 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 981 (class 1247 OID 16804)
-- Name: audit_action; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.audit_action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'LOGIN',
    'LOGOUT',
    'VOID',
    'SESSION_OPEN',
    'SESSION_CLOSE',
    'REPORT_GENERATE',
    'STOCK_ASSIGN'
);


ALTER TYPE public.audit_action OWNER TO postgres;

--
-- TOC entry 978 (class 1247 OID 16798)
-- Name: session_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.session_status AS ENUM (
    'open',
    'closed'
);


ALTER TYPE public.session_status OWNER TO postgres;

--
-- TOC entry 975 (class 1247 OID 16793)
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_role AS ENUM (
    'admin',
    'cashier'
);


ALTER TYPE public.user_role OWNER TO postgres;

--
-- TOC entry 297 (class 1255 OID 17337)
-- Name: fn_guard_closed_session(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_guard_closed_session() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status session_status;
BEGIN
    SELECT status INTO v_status
    FROM cashier_sessions
    WHERE id = NEW.session_id;

    IF v_status = 'closed' THEN
        RAISE EXCEPTION
            'Cannot add entries to a closed session (session_id=%).', NEW.session_id;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_guard_closed_session() OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 17335)
-- Name: fn_protect_audit_logs(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_protect_audit_logs() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs is append-only. Mutation forbidden on id=%', OLD.id;
END;
$$;


ALTER FUNCTION public.fn_protect_audit_logs() OWNER TO postgres;

--
-- TOC entry 343 (class 1255 OID 17331)
-- Name: fn_protect_daily_reports(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_protect_daily_reports() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        'daily_reports rows are immutable. '
        'Delete operation on id=% is forbidden.', OLD.id;
END;
$$;


ALTER FUNCTION public.fn_protect_daily_reports() OWNER TO postgres;

--
-- TOC entry 330 (class 1255 OID 17333)
-- Name: fn_protect_daily_reports_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_protect_daily_reports_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        'daily_reports rows are immutable. '
        'Update operation on id=% is forbidden.', OLD.id;
END;
$$;


ALTER FUNCTION public.fn_protect_daily_reports_update() OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 17327)
-- Name: fn_set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_set_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 250 (class 1259 OID 17251)
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    action public.audit_action NOT NULL,
    table_name character varying(100),
    record_id integer,
    old_values jsonb,
    new_values jsonb,
    description text,
    ip_address inet,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- TOC entry 5465 (class 0 OID 0)
-- Dependencies: 250
-- Name: TABLE audit_logs; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.audit_logs IS 'Append-only audit trail for all system mutations and admin actions. Never update or delete rows from this table.';


--
-- TOC entry 249 (class 1259 OID 17250)
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_logs_id_seq OWNER TO postgres;

--
-- TOC entry 5466 (class 0 OID 0)
-- Dependencies: 249
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_logs_id_seq OWNED BY public.audit_logs.id;


--
-- TOC entry 258 (class 1259 OID 25961)
-- Name: cashier_advances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cashier_advances (
    id integer NOT NULL,
    cashier_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    direction character varying(20) NOT NULL,
    note character varying(1000),
    is_voided boolean DEFAULT false NOT NULL,
    void_reason character varying(500),
    voided_at timestamp with time zone,
    voided_by integer,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    session_id integer,
    CONSTRAINT cashier_advances_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT cashier_advances_direction_check CHECK (((direction)::text = ANY ((ARRAY['advance'::character varying, 'repayment'::character varying])::text[])))
);


ALTER TABLE public.cashier_advances OWNER TO postgres;

--
-- TOC entry 5467 (class 0 OID 0)
-- Dependencies: 258
-- Name: TABLE cashier_advances; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cashier_advances IS 'Ledger for tracking cash advances given to cashiers and their subsequent repayments.';


--
-- TOC entry 257 (class 1259 OID 25960)
-- Name: cashier_advances_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cashier_advances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cashier_advances_id_seq OWNER TO postgres;

--
-- TOC entry 5468 (class 0 OID 0)
-- Dependencies: 257
-- Name: cashier_advances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cashier_advances_id_seq OWNED BY public.cashier_advances.id;


--
-- TOC entry 234 (class 1259 OID 16965)
-- Name: cashier_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cashier_sessions (
    id integer NOT NULL,
    cashier_id integer NOT NULL,
    store_id integer NOT NULL,
    session_date date DEFAULT CURRENT_DATE NOT NULL,
    status public.session_status DEFAULT 'open'::public.session_status NOT NULL,
    opening_cash numeric(12,2) DEFAULT 0 NOT NULL,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    closing_cash numeric(12,2) DEFAULT NULL::numeric,
    cash_discrepancy numeric(12,2) DEFAULT NULL::numeric
);


ALTER TABLE public.cashier_sessions OWNER TO postgres;

--
-- TOC entry 5469 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE cashier_sessions; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cashier_sessions IS 'A cashier work session scoped to a single calendar day.';


--
-- TOC entry 5470 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN cashier_sessions.opening_cash; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cashier_sessions.opening_cash IS 'Cash in register when session opens (admin-set or carry-over).';


--
-- TOC entry 233 (class 1259 OID 16964)
-- Name: cashier_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cashier_sessions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cashier_sessions_id_seq OWNER TO postgres;

--
-- TOC entry 5471 (class 0 OID 0)
-- Dependencies: 233
-- Name: cashier_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cashier_sessions_id_seq OWNED BY public.cashier_sessions.id;


--
-- TOC entry 256 (class 1259 OID 17443)
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    phone_number character varying(20) NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    address text NOT NULL,
    profession character varying(100) NOT NULL,
    notes text,
    created_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    available_points numeric(10,2) DEFAULT 0,
    lifetime_points numeric(10,2) DEFAULT 0,
    referred_by integer,
    referral_rewarded boolean DEFAULT false,
    last_purchase_at timestamp with time zone
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 17442)
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.customers_id_seq OWNER TO postgres;

--
-- TOC entry 5472 (class 0 OID 0)
-- Dependencies: 255
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- TOC entry 248 (class 1259 OID 17205)
-- Name: daily_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.daily_reports (
    id integer NOT NULL,
    report_date date NOT NULL,
    store_id integer NOT NULL,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total_sim_units integer DEFAULT 0 NOT NULL,
    total_real_price numeric(14,2) DEFAULT 0 NOT NULL,
    total_selling_price numeric(14,2) DEFAULT 0 NOT NULL,
    total_points integer DEFAULT 0 NOT NULL,
    total_storm numeric(14,2) DEFAULT 0 NOT NULL,
    total_accessories numeric(14,2) DEFAULT 0 NOT NULL,
    total_debts numeric(14,2) DEFAULT 0 NOT NULL,
    total_commissions numeric(14,2) DEFAULT 0 NOT NULL,
    gross_profit numeric(14,2) DEFAULT 0 NOT NULL,
    snapshot jsonb NOT NULL,
    loyalty_points_redeemed numeric(12,2) DEFAULT 0,
    loyalty_driven_revenue numeric(12,2) DEFAULT 0
);


ALTER TABLE public.daily_reports OWNER TO postgres;

--
-- TOC entry 5473 (class 0 OID 0)
-- Dependencies: 248
-- Name: TABLE daily_reports; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.daily_reports IS 'Immutable end-of-day report. Never updated after creation.';


--
-- TOC entry 5474 (class 0 OID 0)
-- Dependencies: 248
-- Name: COLUMN daily_reports.snapshot; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.daily_reports.snapshot IS 'Full JSONB snapshot of all session data, pool state, and register cash for this day. Structure: { sessions: [{ cashier, sim_sales, storm_entries, accessory_sales, debts, totals }], global_pool: { balance, bonus, points }, register: { cash_amount } }';


--
-- TOC entry 247 (class 1259 OID 17204)
-- Name: daily_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.daily_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.daily_reports_id_seq OWNER TO postgres;

--
-- TOC entry 5475 (class 0 OID 0)
-- Dependencies: 247
-- Name: daily_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.daily_reports_id_seq OWNED BY public.daily_reports.id;


--
-- TOC entry 244 (class 1259 OID 17152)
-- Name: global_pool_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.global_pool_state (
    id integer NOT NULL,
    available_balance numeric(14,2) NOT NULL,
    available_bonus numeric(14,2) DEFAULT 0 NOT NULL,
    available_points integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by integer NOT NULL,
    notes text,
    CONSTRAINT global_pool_state_available_balance_check CHECK ((available_balance >= (0)::numeric)),
    CONSTRAINT global_pool_state_available_bonus_check CHECK ((available_bonus >= (0)::numeric)),
    CONSTRAINT global_pool_state_available_points_check CHECK ((available_points >= 0))
);


ALTER TABLE public.global_pool_state OWNER TO postgres;

--
-- TOC entry 5476 (class 0 OID 0)
-- Dependencies: 244
-- Name: TABLE global_pool_state; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.global_pool_state IS 'Append-only log of admin-set global pool values (balance, bonus, points). Current state = MAX(id) row. Full audit trail retained automatically.';


--
-- TOC entry 5477 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN global_pool_state.available_balance; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.global_pool_state.available_balance IS 'Total DZD balance available across both stores.';


--
-- TOC entry 5478 (class 0 OID 0)
-- Dependencies: 244
-- Name: COLUMN global_pool_state.available_points; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.global_pool_state.available_points IS 'Total loyalty points available in the pool.';


--
-- TOC entry 243 (class 1259 OID 17151)
-- Name: global_pool_state_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.global_pool_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.global_pool_state_id_seq OWNER TO postgres;

--
-- TOC entry 5479 (class 0 OID 0)
-- Dependencies: 243
-- Name: global_pool_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.global_pool_state_id_seq OWNED BY public.global_pool_state.id;


--
-- TOC entry 263 (class 1259 OID 66927)
-- Name: loyalty_ledger; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loyalty_ledger (
    id integer NOT NULL,
    customer_id integer,
    points numeric(10,2) NOT NULL,
    transaction_type character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.loyalty_ledger OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 66926)
-- Name: loyalty_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loyalty_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loyalty_ledger_id_seq OWNER TO postgres;

--
-- TOC entry 5480 (class 0 OID 0)
-- Dependencies: 262
-- Name: loyalty_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loyalty_ledger_id_seq OWNED BY public.loyalty_ledger.id;


--
-- TOC entry 261 (class 1259 OID 66909)
-- Name: loyalty_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loyalty_settings (
    key character varying(50) NOT NULL,
    value numeric NOT NULL,
    description text
);


ALTER TABLE public.loyalty_settings OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 17419)
-- Name: offer_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.offer_categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.offer_categories OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 17418)
-- Name: offer_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.offer_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offer_categories_id_seq OWNER TO postgres;

--
-- TOC entry 5481 (class 0 OID 0)
-- Dependencies: 253
-- Name: offer_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.offer_categories_id_seq OWNED BY public.offer_categories.id;


--
-- TOC entry 228 (class 1259 OID 16892)
-- Name: offers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.offers (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    real_price numeric(12,2) NOT NULL,
    selling_price numeric(12,2) NOT NULL,
    commission_points integer DEFAULT 0 CONSTRAINT offers_points_not_null NOT NULL,
    commission_amount numeric(12,2) DEFAULT 0 NOT NULL,
    low_stock_threshold integer DEFAULT 5 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    category_id integer NOT NULL,
    loyalty_points numeric(10,2) DEFAULT 0,
    CONSTRAINT offers_commission_amount_check CHECK ((commission_amount >= (0)::numeric)),
    CONSTRAINT offers_low_stock_threshold_check CHECK ((low_stock_threshold >= 0)),
    CONSTRAINT offers_points_check CHECK ((commission_points >= 0)),
    CONSTRAINT offers_real_price_check CHECK ((real_price >= (0)::numeric)),
    CONSTRAINT offers_selling_price_check CHECK ((selling_price >= (0)::numeric))
);


ALTER TABLE public.offers OWNER TO postgres;

--
-- TOC entry 5482 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE offers; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.offers IS 'SIM card offer types. Admin-configurable.';


--
-- TOC entry 5483 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN offers.real_price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.offers.real_price IS 'Buying/cost price in DZD.';


--
-- TOC entry 5484 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN offers.selling_price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.offers.selling_price IS 'Price charged to customer in DZD.';


--
-- TOC entry 5485 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN offers.commission_points; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.offers.commission_points IS 'Loyalty points generated per unit sold.';


--
-- TOC entry 5486 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN offers.commission_amount; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.offers.commission_amount IS 'Cashier commission per unit sold in DZD.';


--
-- TOC entry 5487 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN offers.low_stock_threshold; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.offers.low_stock_threshold IS 'Alert admin when assigned stock falls below this.';


--
-- TOC entry 5488 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN offers.sort_order; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.offers.sort_order IS 'Controls display order of offer buttons in UI.';


--
-- TOC entry 227 (class 1259 OID 16891)
-- Name: offers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.offers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offers_id_seq OWNER TO postgres;

--
-- TOC entry 5489 (class 0 OID 0)
-- Dependencies: 227
-- Name: offers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.offers_id_seq OWNED BY public.offers.id;


--
-- TOC entry 230 (class 1259 OID 16922)
-- Name: product_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.product_categories OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16921)
-- Name: product_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_categories_id_seq OWNER TO postgres;

--
-- TOC entry 5490 (class 0 OID 0)
-- Dependencies: 229
-- Name: product_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_categories_id_seq OWNED BY public.product_categories.id;


--
-- TOC entry 232 (class 1259 OID 16937)
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    price numeric(12,2) NOT NULL,
    category_id integer NOT NULL,
    commission_amount numeric(12,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    real_price numeric(12,2) NOT NULL,
    barcode character varying(100),
    low_stock_threshold integer DEFAULT 5,
    loyalty_points numeric(10,2) DEFAULT 0,
    CONSTRAINT products_commission_amount_check CHECK ((commission_amount >= (0)::numeric)),
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_real_price_check CHECK ((real_price >= (0)::numeric))
);


ALTER TABLE public.products OWNER TO postgres;

--
-- TOC entry 5491 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE products; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.products IS 'Phone, PC, and accessory product catalogue. Admin-configurable.';


--
-- TOC entry 5492 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN products.price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.products.price IS 'Selling price in DZD. Snapshotted at time of sale.';


--
-- TOC entry 5493 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN products.commission_amount; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.products.commission_amount IS 'Cashier commission per unit sold in DZD.';


--
-- TOC entry 5494 (class 0 OID 0)
-- Dependencies: 232
-- Name: COLUMN products.real_price; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.products.real_price IS 'Cost/buying price in DZD. Used for profit calculation.';


--
-- TOC entry 231 (class 1259 OID 16936)
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_id_seq OWNER TO postgres;

--
-- TOC entry 5495 (class 0 OID 0)
-- Dependencies: 231
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- TOC entry 226 (class 1259 OID 16868)
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.refresh_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token_hash character varying(255) NOT NULL,
    issued_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    is_revoked boolean DEFAULT false NOT NULL,
    revoked_at timestamp with time zone,
    ip_address inet
);


ALTER TABLE public.refresh_tokens OWNER TO postgres;

--
-- TOC entry 5496 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.refresh_tokens IS 'Hashed refresh tokens for JWT rotation.';


--
-- TOC entry 5497 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN refresh_tokens.token_hash; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.refresh_tokens.token_hash IS 'SHA-256 of the random token sent to client.';


--
-- TOC entry 225 (class 1259 OID 16867)
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.refresh_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.refresh_tokens_id_seq OWNER TO postgres;

--
-- TOC entry 5498 (class 0 OID 0)
-- Dependencies: 225
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.refresh_tokens_id_seq OWNED BY public.refresh_tokens.id;


--
-- TOC entry 260 (class 1259 OID 26004)
-- Name: register_expenses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.register_expenses (
    id integer NOT NULL,
    session_id integer,
    store_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    category character varying(50) NOT NULL,
    description character varying(1000),
    expense_date date DEFAULT CURRENT_DATE NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    void_reason character varying(500),
    voided_at timestamp with time zone,
    voided_by integer,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT register_expenses_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT register_expenses_category_check CHECK (((category)::text = ANY ((ARRAY['utility'::character varying, 'inventory'::character varying, 'other'::character varying])::text[])))
);


ALTER TABLE public.register_expenses OWNER TO postgres;

--
-- TOC entry 5499 (class 0 OID 0)
-- Dependencies: 260
-- Name: TABLE register_expenses; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.register_expenses IS 'Tracks physical cash removed from the register for operational expenses.';


--
-- TOC entry 259 (class 1259 OID 26003)
-- Name: register_expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.register_expenses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.register_expenses_id_seq OWNER TO postgres;

--
-- TOC entry 5500 (class 0 OID 0)
-- Dependencies: 259
-- Name: register_expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.register_expenses_id_seq OWNED BY public.register_expenses.id;


--
-- TOC entry 240 (class 1259 OID 17090)
-- Name: session_accessory_sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_accessory_sales (
    id integer NOT NULL,
    session_id integer NOT NULL,
    product_id integer,
    product_name_snapshot character varying(200) NOT NULL,
    category_name_snapshot character varying(50) NOT NULL,
    price_snapshot numeric(12,2) NOT NULL,
    commission_snapshot numeric(12,2) DEFAULT 0 NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by integer,
    void_reason text,
    sold_at timestamp with time zone DEFAULT now() NOT NULL,
    real_price_snapshot numeric(12,2) NOT NULL,
    customer_id integer,
    loyalty_earned_snapshot numeric(10,2) DEFAULT 0,
    loyalty_redeemed_snapshot numeric(10,2) DEFAULT 0
);


ALTER TABLE public.session_accessory_sales OWNER TO postgres;

--
-- TOC entry 5501 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE session_accessory_sales; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.session_accessory_sales IS 'One row = one phone/PC/accessory unit sold within a session.';


--
-- TOC entry 239 (class 1259 OID 17089)
-- Name: session_accessory_sales_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_accessory_sales_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_accessory_sales_id_seq OWNER TO postgres;

--
-- TOC entry 5502 (class 0 OID 0)
-- Dependencies: 239
-- Name: session_accessory_sales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_accessory_sales_id_seq OWNED BY public.session_accessory_sales.id;


--
-- TOC entry 242 (class 1259 OID 17125)
-- Name: session_debts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_debts (
    id integer NOT NULL,
    session_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    description text,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by integer,
    void_reason text,
    entered_at timestamp with time zone DEFAULT now() NOT NULL,
    customer_id integer,
    CONSTRAINT session_debts_amount_check CHECK ((amount > (0)::numeric))
);


ALTER TABLE public.session_debts OWNER TO postgres;

--
-- TOC entry 5503 (class 0 OID 0)
-- Dependencies: 242
-- Name: TABLE session_debts; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.session_debts IS 'Debt entries recorded by a cashier within a session.';


--
-- TOC entry 241 (class 1259 OID 17124)
-- Name: session_debts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_debts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_debts_id_seq OWNER TO postgres;

--
-- TOC entry 5504 (class 0 OID 0)
-- Dependencies: 241
-- Name: session_debts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_debts_id_seq OWNED BY public.session_debts.id;


--
-- TOC entry 236 (class 1259 OID 17027)
-- Name: session_sim_sales; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_sim_sales (
    id integer NOT NULL,
    session_id integer NOT NULL,
    offer_id integer NOT NULL,
    offer_name_snapshot character varying(100) NOT NULL,
    real_price_snapshot numeric(12,2) NOT NULL,
    selling_price_snapshot numeric(12,2) NOT NULL,
    commission_points_snapshot integer CONSTRAINT session_sim_sales_points_snapshot_not_null NOT NULL,
    commission_snapshot numeric(12,2) NOT NULL,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by integer,
    void_reason text,
    sold_at timestamp with time zone DEFAULT now() NOT NULL,
    customer_id integer,
    discount_snapshot numeric(12,2) DEFAULT 0 NOT NULL,
    loyalty_earned_snapshot numeric(10,2) DEFAULT 0,
    loyalty_redeemed_snapshot numeric(10,2) DEFAULT 0,
    CONSTRAINT session_sim_sales_discount_snapshot_check CHECK ((discount_snapshot >= (0)::numeric))
);


ALTER TABLE public.session_sim_sales OWNER TO postgres;

--
-- TOC entry 5505 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE session_sim_sales; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.session_sim_sales IS 'One row = one SIM card unit sold within a session.';


--
-- TOC entry 5506 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN session_sim_sales.is_voided; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.session_sim_sales.is_voided IS 'Soft-delete. Voided rows excluded from all totals.';


--
-- TOC entry 5507 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN session_sim_sales.discount_snapshot; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.session_sim_sales.discount_snapshot IS 'Amount discounted from the standard selling price at the time of sale.';


--
-- TOC entry 235 (class 1259 OID 17026)
-- Name: session_sim_sales_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_sim_sales_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_sim_sales_id_seq OWNER TO postgres;

--
-- TOC entry 5508 (class 0 OID 0)
-- Dependencies: 235
-- Name: session_sim_sales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_sim_sales_id_seq OWNED BY public.session_sim_sales.id;


--
-- TOC entry 238 (class 1259 OID 17063)
-- Name: session_storm_entries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_storm_entries (
    id integer NOT NULL,
    session_id integer NOT NULL,
    amount numeric(12,2) NOT NULL,
    note text,
    is_voided boolean DEFAULT false NOT NULL,
    voided_at timestamp with time zone,
    voided_by integer,
    void_reason text,
    entered_at timestamp with time zone DEFAULT now() NOT NULL,
    customer_id integer,
    loyalty_earned_snapshot numeric(10,2) DEFAULT 0,
    loyalty_redeemed_snapshot numeric(10,2) DEFAULT 0,
    CONSTRAINT session_storm_entries_amount_check CHECK ((amount > (0)::numeric))
);


ALTER TABLE public.session_storm_entries OWNER TO postgres;

--
-- TOC entry 5509 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE session_storm_entries; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.session_storm_entries IS 'Manual Storm/Bundle purchase amounts. One row per cashier entry.';


--
-- TOC entry 237 (class 1259 OID 17062)
-- Name: session_storm_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_storm_entries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.session_storm_entries_id_seq OWNER TO postgres;

--
-- TOC entry 5510 (class 0 OID 0)
-- Dependencies: 237
-- Name: session_storm_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_storm_entries_id_seq OWNED BY public.session_storm_entries.id;


--
-- TOC entry 265 (class 1259 OID 66964)
-- Name: sim_balances; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sim_balances (
    id integer NOT NULL,
    owner_type character varying(20) NOT NULL,
    owner_id integer NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    CONSTRAINT sim_balances_owner_type_check CHECK (((owner_type)::text = ANY ((ARRAY['store'::character varying, 'cashier'::character varying, 'admin'::character varying])::text[]))),
    CONSTRAINT sim_balances_quantity_check CHECK ((quantity >= 0))
);


ALTER TABLE public.sim_balances OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 66963)
-- Name: sim_balances_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sim_balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sim_balances_id_seq OWNER TO postgres;

--
-- TOC entry 5511 (class 0 OID 0)
-- Dependencies: 264
-- Name: sim_balances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sim_balances_id_seq OWNED BY public.sim_balances.id;


--
-- TOC entry 246 (class 1259 OID 17178)
-- Name: store_register_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.store_register_state (
    id integer NOT NULL,
    store_id integer NOT NULL,
    cash_amount numeric(12,2) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by integer NOT NULL,
    notes text,
    CONSTRAINT store_register_state_cash_amount_check CHECK ((cash_amount >= (0)::numeric))
);


ALTER TABLE public.store_register_state OWNER TO postgres;

--
-- TOC entry 5512 (class 0 OID 0)
-- Dependencies: 246
-- Name: TABLE store_register_state; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.store_register_state IS 'Append-only log of admin-set per-store cash register amounts. Current state = MAX(id) WHERE store_id = X.';


--
-- TOC entry 245 (class 1259 OID 17177)
-- Name: store_register_state_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.store_register_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.store_register_state_id_seq OWNER TO postgres;

--
-- TOC entry 5513 (class 0 OID 0)
-- Dependencies: 245
-- Name: store_register_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.store_register_state_id_seq OWNED BY public.store_register_state.id;


--
-- TOC entry 222 (class 1259 OID 16826)
-- Name: stores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stores (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    location character varying(200),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.stores OWNER TO postgres;

--
-- TOC entry 5514 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE stores; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.stores IS 'Physical store locations.';


--
-- TOC entry 5515 (class 0 OID 0)
-- Dependencies: 222
-- Name: COLUMN stores.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.stores.name IS 'Display name, e.g. "AAO Sobha", "Kiosque Ain Meraine".';


--
-- TOC entry 221 (class 1259 OID 16825)
-- Name: stores_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stores_id_seq OWNER TO postgres;

--
-- TOC entry 5516 (class 0 OID 0)
-- Dependencies: 221
-- Name: stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stores_id_seq OWNED BY public.stores.id;


--
-- TOC entry 224 (class 1259 OID 16841)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    password_hash character varying(255) NOT NULL,
    full_name character varying(100) NOT NULL,
    role public.user_role DEFAULT 'cashier'::public.user_role NOT NULL,
    store_id integer,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cashier_requires_store CHECK (((role = 'admin'::public.user_role) OR (store_id IS NOT NULL)))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 5517 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.users IS 'System users: one admin + four cashiers.';


--
-- TOC entry 5518 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN users.password_hash; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.password_hash IS 'bcrypt hash. Never store plaintext.';


--
-- TOC entry 5519 (class 0 OID 0)
-- Dependencies: 224
-- Name: COLUMN users.store_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.users.store_id IS 'NULL for admin. Required for cashiers.';


--
-- TOC entry 223 (class 1259 OID 16840)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 5520 (class 0 OID 0)
-- Dependencies: 223
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 251 (class 1259 OID 17314)
-- Name: v_current_pool; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_current_pool AS
 SELECT available_balance,
    available_bonus,
    available_points,
    updated_at,
    updated_by
   FROM public.global_pool_state
  ORDER BY id DESC
 LIMIT 1;


ALTER VIEW public.v_current_pool OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 17318)
-- Name: v_current_register; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_current_register AS
 SELECT DISTINCT ON (store_id) store_id,
    cash_amount,
    updated_at,
    updated_by
   FROM public.store_register_state
  ORDER BY store_id, id DESC;


ALTER VIEW public.v_current_register OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 66984)
-- Name: v_session_live_totals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_session_live_totals AS
SELECT
    NULL::integer AS session_id,
    NULL::integer AS cashier_id,
    NULL::character varying(100) AS cashier_name,
    NULL::integer AS store_id,
    NULL::character varying(100) AS store_name,
    NULL::date AS session_date,
    NULL::numeric(12,2) AS opening_cash,
    NULL::bigint AS sim_units_sold,
    NULL::numeric AS sim_total_real_price,
    NULL::numeric AS sim_total_selling_price,
    NULL::bigint AS sim_total_points,
    NULL::numeric AS sim_total_commission,
    NULL::numeric AS sim_total_profit,
    NULL::numeric AS storm_total,
    NULL::numeric AS accessories_total,
    NULL::numeric AS accessories_total_real_price,
    NULL::numeric AS accessories_total_commission,
    NULL::numeric AS accessories_total_profit,
    NULL::numeric AS debt_total,
    NULL::numeric AS expected_register_cash,
    NULL::numeric AS total_cashier_benefit,
    NULL::numeric AS loyalty_points_redeemed,
    NULL::numeric AS loyalty_driven_revenue;


ALTER VIEW public.v_session_live_totals OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 66989)
-- Name: v_monthly_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_monthly_summary AS
 SELECT (date_trunc('month'::text, (cs.session_date)::timestamp with time zone))::date AS month,
    cs.store_id,
    count(DISTINCT cs.session_date) AS days_with_activity,
    sum(v.sim_units_sold) AS total_sim_units,
    sum(v.sim_total_selling_price) AS total_selling_price,
    sum(v.sim_total_real_price) AS total_real_price,
    sum(v.storm_total) AS total_storm,
    sum(v.accessories_total) AS total_accessories,
    sum(v.total_cashier_benefit) AS total_commissions,
    sum(v.debt_total) AS total_debts,
    sum((v.sim_total_profit + v.accessories_total_profit)) AS gross_profit,
    sum(v.loyalty_points_redeemed) AS loyalty_points_redeemed,
    sum(v.loyalty_driven_revenue) AS loyalty_driven_revenue
   FROM (public.v_session_live_totals v
     JOIN public.cashier_sessions cs ON ((cs.id = v.session_id)))
  GROUP BY ((date_trunc('month'::text, (cs.session_date)::timestamp with time zone))::date), cs.store_id;


ALTER VIEW public.v_monthly_summary OWNER TO postgres;

--
-- TOC entry 5053 (class 2604 OID 17254)
-- Name: audit_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN id SET DEFAULT nextval('public.audit_logs_id_seq'::regclass);


--
-- TOC entry 5065 (class 2604 OID 25964)
-- Name: cashier_advances id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_advances ALTER COLUMN id SET DEFAULT nextval('public.cashier_advances_id_seq'::regclass);


--
-- TOC entry 5006 (class 2604 OID 16968)
-- Name: cashier_sessions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_sessions ALTER COLUMN id SET DEFAULT nextval('public.cashier_sessions_id_seq'::regclass);


--
-- TOC entry 5059 (class 2604 OID 17446)
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- TOC entry 5040 (class 2604 OID 17208)
-- Name: daily_reports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_reports ALTER COLUMN id SET DEFAULT nextval('public.daily_reports_id_seq'::regclass);


--
-- TOC entry 5033 (class 2604 OID 17155)
-- Name: global_pool_state id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_pool_state ALTER COLUMN id SET DEFAULT nextval('public.global_pool_state_id_seq'::regclass);


--
-- TOC entry 5072 (class 2604 OID 66930)
-- Name: loyalty_ledger id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_ledger ALTER COLUMN id SET DEFAULT nextval('public.loyalty_ledger_id_seq'::regclass);


--
-- TOC entry 5055 (class 2604 OID 17422)
-- Name: offer_categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offer_categories ALTER COLUMN id SET DEFAULT nextval('public.offer_categories_id_seq'::regclass);


--
-- TOC entry 4986 (class 2604 OID 16895)
-- Name: offers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offers ALTER COLUMN id SET DEFAULT nextval('public.offers_id_seq'::regclass);


--
-- TOC entry 4995 (class 2604 OID 16925)
-- Name: product_categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_categories ALTER COLUMN id SET DEFAULT nextval('public.product_categories_id_seq'::regclass);


--
-- TOC entry 4998 (class 2604 OID 16940)
-- Name: products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- TOC entry 4983 (class 2604 OID 16871)
-- Name: refresh_tokens id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('public.refresh_tokens_id_seq'::regclass);


--
-- TOC entry 5068 (class 2604 OID 26007)
-- Name: register_expenses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.register_expenses ALTER COLUMN id SET DEFAULT nextval('public.register_expenses_id_seq'::regclass);


--
-- TOC entry 5024 (class 2604 OID 17093)
-- Name: session_accessory_sales id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_accessory_sales ALTER COLUMN id SET DEFAULT nextval('public.session_accessory_sales_id_seq'::regclass);


--
-- TOC entry 5030 (class 2604 OID 17128)
-- Name: session_debts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_debts ALTER COLUMN id SET DEFAULT nextval('public.session_debts_id_seq'::regclass);


--
-- TOC entry 5013 (class 2604 OID 17030)
-- Name: session_sim_sales id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_sim_sales ALTER COLUMN id SET DEFAULT nextval('public.session_sim_sales_id_seq'::regclass);


--
-- TOC entry 5019 (class 2604 OID 17066)
-- Name: session_storm_entries id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_storm_entries ALTER COLUMN id SET DEFAULT nextval('public.session_storm_entries_id_seq'::regclass);


--
-- TOC entry 5074 (class 2604 OID 66967)
-- Name: sim_balances id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sim_balances ALTER COLUMN id SET DEFAULT nextval('public.sim_balances_id_seq'::regclass);


--
-- TOC entry 5037 (class 2604 OID 17181)
-- Name: store_register_state id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store_register_state ALTER COLUMN id SET DEFAULT nextval('public.store_register_state_id_seq'::regclass);


--
-- TOC entry 4975 (class 2604 OID 16829)
-- Name: stores id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stores ALTER COLUMN id SET DEFAULT nextval('public.stores_id_seq'::regclass);


--
-- TOC entry 4978 (class 2604 OID 16844)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5444 (class 0 OID 17251)
-- Dependencies: 250
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (id, user_id, action, table_name, record_id, old_values, new_values, description, ip_address, created_at) FROM stdin;
1	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 21:12:20.522766+02
2	1	INSERT	offers	1	\N	{"id": 1, "name": "Ooredoo Internet 1500", "points": 150, "is_active": true, "created_at": "2026-08-09T19:25:58.312Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:25:58.312Z", "category_id": 6, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:25:58.333432+02
3	1	INSERT	offers	2	\N	{"id": 2, "name": "Ooredoo Internet 2500", "points": 500, "is_active": true, "created_at": "2026-08-09T19:26:30.345Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:26:30.345Z", "category_id": 6, "selling_price": 2500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:26:30.349654+02
4	1	INSERT	offers	3	\N	{"id": 3, "name": "Ooredoo Internet 4500", "points": 900, "is_active": true, "created_at": "2026-08-09T19:26:51.995Z", "real_price": 4500, "sort_order": 0, "updated_at": "2026-08-09T19:26:51.995Z", "category_id": 6, "selling_price": 4500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:26:51.996989+02
5	1	INSERT	offers	4	\N	{"id": 4, "name": "Ooredoo Internet 5500", "points": 1100, "is_active": true, "created_at": "2026-08-09T19:27:15.405Z", "real_price": 5500, "sort_order": 0, "updated_at": "2026-08-09T19:27:15.405Z", "category_id": 6, "selling_price": 5500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:27:15.406513+02
6	1	INSERT	offers	5	\N	{"id": 5, "name": "Ooredoo Internet 10000", "points": 2000, "is_active": true, "created_at": "2026-08-09T19:27:35.838Z", "real_price": 10000, "sort_order": 0, "updated_at": "2026-08-09T19:27:35.838Z", "category_id": 6, "selling_price": 10000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:27:35.84085+02
7	1	INSERT	offers	6	\N	{"id": 6, "name": "Ooredoo Internet 19500", "points": 3900, "is_active": true, "created_at": "2026-08-09T19:27:53.748Z", "real_price": 19500, "sort_order": 0, "updated_at": "2026-08-09T19:27:53.748Z", "category_id": 6, "selling_price": 19500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:27:53.749997+02
8	1	INSERT	offers	7	\N	{"id": 7, "name": "Ooredoo 500", "points": 100, "is_active": true, "created_at": "2026-08-09T19:28:22.840Z", "real_price": 500, "sort_order": 0, "updated_at": "2026-08-09T19:28:22.840Z", "category_id": 4, "selling_price": 500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:28:22.841836+02
9	1	INSERT	offers	8	\N	{"id": 8, "name": "2500 : Ooredoo 500 * 6", "points": 1125, "is_active": true, "created_at": "2026-08-09T19:28:54.819Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:28:54.819Z", "category_id": 4, "selling_price": 2500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:28:54.824828+02
10	1	INSERT	offers	9	\N	{"id": 9, "name": "3500 : Ooredoo 500 * 9", "points": 1050, "is_active": true, "created_at": "2026-08-09T19:29:27.390Z", "real_price": 3500, "sort_order": 0, "updated_at": "2026-08-09T19:29:27.390Z", "category_id": 4, "selling_price": 3500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:29:27.396002+02
11	1	INSERT	offers	10	\N	{"id": 10, "name": "4500 : Ooredoo 500 * 12", "points": 1350, "is_active": true, "created_at": "2026-08-09T19:29:59.463Z", "real_price": 4500, "sort_order": 0, "updated_at": "2026-08-09T19:29:59.463Z", "category_id": 4, "selling_price": 4500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:29:59.469466+02
12	1	INSERT	offers	11	\N	{"id": 11, "name": "4990 : 200Go + Ooredoo 500 * 12", "points": 1200, "is_active": true, "created_at": "2026-08-09T19:30:31.336Z", "real_price": 4990, "sort_order": 0, "updated_at": "2026-08-09T19:30:31.336Z", "category_id": 4, "selling_price": 4990, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:30:31.341955+02
13	1	INSERT	offers	12	\N	{"id": 12, "name": "Dima 1200", "points": 300, "is_active": true, "created_at": "2026-08-09T19:31:05.178Z", "real_price": 1200, "sort_order": 0, "updated_at": "2026-08-09T19:31:05.178Z", "category_id": 3, "selling_price": 1200, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:31:05.183461+02
14	1	INSERT	offers	13	\N	{"id": 13, "name": "Dima 500", "points": 0, "is_active": true, "created_at": "2026-08-09T19:31:20.536Z", "real_price": 500, "sort_order": 0, "updated_at": "2026-08-09T19:31:20.536Z", "category_id": 3, "selling_price": 500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:31:20.537372+02
15	1	INSERT	offers	14	\N	{"id": 14, "name": "Dima 1500", "points": 375, "is_active": true, "created_at": "2026-08-09T19:31:36.791Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:31:36.791Z", "category_id": 3, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:31:36.792352+02
16	1	INSERT	offers	15	\N	{"id": 15, "name": "Dima 2000", "points": 500, "is_active": true, "created_at": "2026-08-09T19:32:01.092Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:32:01.092Z", "category_id": 3, "selling_price": 2000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:32:01.093924+02
17	1	INSERT	offers	16	\N	{"id": 16, "name": "Dima 2500", "points": 1250, "is_active": true, "created_at": "2026-08-09T19:32:19.892Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:32:19.892Z", "category_id": 3, "selling_price": 1700, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:32:19.893434+02
18	1	INSERT	offers	17	\N	{"id": 17, "name": "Gold 1000", "points": 250, "is_active": true, "created_at": "2026-08-09T19:32:43.026Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-09T19:32:43.026Z", "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:32:43.027889+02
19	1	INSERT	offers	18	\N	{"id": 18, "name": "Gold 1500", "points": 375, "is_active": true, "created_at": "2026-08-09T19:32:53.921Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:32:53.921Z", "category_id": 1, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:32:53.921976+02
46	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-09 22:49:48.397354+02
20	1	INSERT	offers	19	\N	{"id": 19, "name": "La Gold 2000", "points": 500, "is_active": true, "created_at": "2026-08-09T19:33:15.933Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:33:15.933Z", "category_id": 1, "selling_price": 2000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:33:15.934383+02
21	1	INSERT	offers	20	\N	{"id": 20, "name": "La Gold 2500", "points": 1250, "is_active": true, "created_at": "2026-08-09T19:33:29.523Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:33:29.523Z", "category_id": 1, "selling_price": 1700, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:33:29.525123+02
22	1	UPDATE	offers	17	{"id": 17, "name": "Gold 1000", "points": 250, "is_active": true, "created_at": "2026-08-09T19:32:43.026Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-09T19:32:43.026Z", "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	{"name": "La Gold 1000", "points": 250, "real_price": 1000, "sort_order": 0, "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:33:44.051142+02
23	1	UPDATE	offers	18	{"id": 18, "name": "Gold 1500", "points": 375, "is_active": true, "created_at": "2026-08-09T19:32:53.921Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:32:53.921Z", "category_id": 1, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	{"name": "La Gold 1500", "points": 375, "real_price": 1500, "sort_order": 0, "category_id": 1, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:33:50.777311+02
24	1	INSERT	offers	21	\N	{"id": 21, "name": "N'YOOZ 300", "points": 0, "is_active": true, "created_at": "2026-08-09T19:34:17.832Z", "real_price": 300, "sort_order": 0, "updated_at": "2026-08-09T19:34:17.832Z", "category_id": 2, "selling_price": 300, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:34:17.833589+02
25	1	INSERT	offers	22	\N	{"id": 22, "name": "N'YOOZ 500", "points": 0, "is_active": true, "created_at": "2026-08-09T19:34:27.675Z", "real_price": 500, "sort_order": 0, "updated_at": "2026-08-09T19:34:27.675Z", "category_id": 2, "selling_price": 500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:34:27.676812+02
26	1	INSERT	offers	23	\N	{"id": 23, "name": "N'YOOZ 1000", "points": 250, "is_active": true, "created_at": "2026-08-09T19:34:48.637Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-09T19:34:48.637Z", "category_id": 2, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:34:48.63934+02
27	1	INSERT	offers	24	\N	{"id": 24, "name": "N'YOOZ 1500", "points": 375, "is_active": true, "created_at": "2026-08-09T19:35:04.610Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:35:04.610Z", "category_id": 2, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:35:04.611273+02
28	1	INSERT	offers	25	\N	{"id": 25, "name": "Ooredoo POP 1500", "points": 150, "is_active": true, "created_at": "2026-08-09T19:35:38.455Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:35:38.455Z", "category_id": 5, "selling_price": 1500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:35:38.459714+02
29	1	INSERT	offers	26	\N	{"id": 26, "name": "Ooredoo POP 2000", "points": 200, "is_active": true, "created_at": "2026-08-09T19:35:55.762Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:35:55.762Z", "category_id": 5, "selling_price": 2000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:35:55.764084+02
30	1	INSERT	offers	27	\N	{"id": 27, "name": "Ooredoo POP 2000 0550", "points": 0, "is_active": true, "created_at": "2026-08-09T19:36:21.596Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:36:21.596Z", "category_id": 5, "selling_price": 2000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:36:21.598217+02
31	1	INSERT	offers	28	\N	{"id": 28, "name": "Ooredoo POP 2500", "points": 750, "is_active": true, "created_at": "2026-08-09T19:36:38.163Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:36:38.163Z", "category_id": 5, "selling_price": 2500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:36:38.164438+02
32	1	INSERT	offers	29	\N	{"id": 29, "name": "Ooredoo POP 4000", "points": 1200, "is_active": true, "created_at": "2026-08-09T19:36:53.827Z", "real_price": 4000, "sort_order": 0, "updated_at": "2026-08-09T19:36:53.827Z", "category_id": 5, "selling_price": 4000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:36:53.828796+02
33	1	INSERT	users	2	\N	{"role": "cashier", "store_id": "1", "username": "aymen_sobha"}	\N	154.242.183.125	2026-08-09 21:38:43.626068+02
34	1	INSERT	users	3	\N	{"role": "cashier", "store_id": "1", "username": "fatiha_sobha"}	\N	154.242.183.125	2026-08-09 21:39:00.826009+02
35	1	INSERT	users	4	\N	{"role": "cashier", "store_id": 2, "username": "aziz_ainmeraine"}	\N	154.242.183.125	2026-08-09 21:39:20.909033+02
36	1	INSERT	users	5	\N	{"role": "cashier", "store_id": 2, "username": "hadil_ainmeraine"}	\N	154.242.183.125	2026-08-09 21:39:42.763743+02
37	1	INSERT	users	6	\N	{"role": "cashier", "store_id": 2, "username": "sarri_ainmeraine"}	\N	154.242.183.125	2026-08-09 21:40:24.811417+02
38	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-09 21:40:31.324839+02
39	2	SESSION_OPEN	cashier_sessions	1	\N	{"store_id": 1, "cashier_id": 2, "opening_cash": 0}	\N	154.242.183.125	2026-08-09 21:40:38.55451+02
40	1	INSERT	customers	1	\N	{"phone": "000000", "last_name": "Customer", "first_name": "Junk"}	\N	154.242.183.125	2026-08-09 21:42:04.398176+02
41	1	INSERT	products	1	\N	{"id": 1, "name": "Samsung Galaxy A56 5G 8/128", "price": 55000, "barcode": "125060", "is_active": true, "created_at": "2026-08-09T19:59:46.694Z", "real_price": 53000, "sort_order": 0, "updated_at": "2026-08-09T19:59:46.694Z", "category_id": 6, "commission_amount": 0, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-09 21:59:46.717186+02
43	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-09 22:16:42.737878+02
42	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-09 22:16:42.738892+02
44	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 22:16:46.875979+02
45	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-09 22:49:48.386489+02
47	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-09 22:50:27.41305+02
48	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.183.125	2026-08-09 22:50:38.226161+02
49	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-09 22:50:39.821449+02
50	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 22:59:09.69814+02
51	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 23:00:11.72778+02
52	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 23:00:14.621378+02
53	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 23:01:35.67534+02
54	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 23:02:57.486822+02
55	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 23:04:28.113914+02
56	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-09 23:24:40.505822+02
57	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.46477+02
58	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.473531+02
59	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.474127+02
60	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.479674+02
61	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.506987+02
63	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.528588+02
62	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.528109+02
64	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.547237+02
65	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.551428+02
68	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.582386+02
66	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.581407+02
67	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.58192+02
69	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:31.599017+02
70	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:56.890897+02
71	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:56.986907+02
72	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:57.038565+02
73	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 00:57:57.050273+02
74	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 09:07:31.349102+02
75	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-10 09:23:45.607643+02
76	2	SESSION_CLOSE	cashier_sessions	1	\N	\N	\N	154.242.183.125	2026-08-10 09:23:50.533002+02
77	2	SESSION_OPEN	cashier_sessions	2	\N	{"store_id": 1, "cashier_id": 2, "opening_cash": 0}	\N	154.242.183.125	2026-08-10 09:23:51.79313+02
78	2	INSERT	customers	2	\N	{"phone": "0554198047", "last_name": "MEROUAN", "first_name": "BENSID AHMED"}	\N	154.242.183.125	2026-08-10 09:25:49.327944+02
79	2	INSERT	session_storm_entries	1	\N	\N	\N	154.242.183.125	2026-08-10 09:25:49.960982+02
80	2	INSERT	session_storm_entries	2	\N	\N	\N	154.242.183.125	2026-08-10 09:29:06.709485+02
81	2	INSERT	customers	3	\N	{"phone": "0550907433", "last_name": "ABDELKHALAQ", "first_name": "ZID ELKHIR"}	\N	154.242.183.125	2026-08-10 09:31:47.069269+02
82	2	INSERT	session_storm_entries	3	\N	\N	\N	154.242.183.125	2026-08-10 09:31:47.35309+02
83	2	INSERT	customers	4	\N	{"phone": "0564045873", "last_name": "AMRI", "first_name": "HOURIA"}	\N	154.242.183.125	2026-08-10 09:36:23.816237+02
84	2	INSERT	session_sim_sales	1	\N	{"offer_id": 7, "customer_id": 4}	\N	154.242.183.125	2026-08-10 09:43:24.65318+02
85	2	INSERT	session_storm_entries	4	\N	\N	\N	154.242.183.125	2026-08-10 10:06:12.0477+02
86	2	INSERT	customers	5	\N	{"phone": "0564004546", "last_name": "MOUSSAOUI", "first_name": "HAMID"}	\N	154.242.183.125	2026-08-10 10:07:13.616798+02
87	1	UPDATE	offers	20	{"id": 20, "name": "La Gold 2500", "points": 1250, "is_active": true, "created_at": "2026-08-09T19:33:29.523Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:33:29.523Z", "category_id": 1, "selling_price": 1700, "commission_amount": 50, "low_stock_threshold": 5}	{"name": "La Gold 2500", "points": 1250, "real_price": 2500, "sort_order": 0, "category_id": 1, "selling_price": 2500, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.183.125	2026-08-10 10:07:33.668198+02
88	2	INSERT	session_sim_sales	2	\N	{"offer_id": 20, "customer_id": 5}	\N	154.242.183.125	2026-08-10 10:08:01.716941+02
89	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-10 10:08:27.752916+02
90	2	INSERT	session_storm_entries	5	\N	\N	\N	154.242.183.125	2026-08-10 10:12:34.599351+02
91	2	INSERT	customers	6	\N	{"phone": "0564011034", "last_name": "NOURINE", "first_name": "LAIKA"}	\N	154.242.183.125	2026-08-10 10:18:24.601803+02
92	2	INSERT	session_sim_sales	3	\N	{"offer_id": 19, "customer_id": 6}	\N	154.242.183.125	2026-08-10 10:18:26.210571+02
93	2	INSERT	customers	7	\N	{"phone": "0550684621", "last_name": "Hamadi", "first_name": "AbdElKader"}	\N	154.242.183.125	2026-08-10 10:33:57.050341+02
94	2	INSERT	session_storm_entries	6	\N	\N	\N	154.242.183.125	2026-08-10 10:33:57.359083+02
95	2	INSERT	session_sim_sales	4	\N	{"offer_id": 18, "customer_id": 1}	\N	154.242.183.125	2026-08-10 10:37:04.950364+02
96	2	INSERT	customers	8	\N	{"phone": "0561444340", "last_name": "Kharoubi", "first_name": "Mohamed"}	\N	154.242.183.125	2026-08-10 10:41:34.238996+02
97	2	INSERT	session_storm_entries	7	\N	\N	\N	154.242.183.125	2026-08-10 10:41:34.640554+02
98	2	INSERT	session_storm_entries	8	\N	\N	\N	154.242.183.125	2026-08-10 10:52:02.775426+02
99	2	INSERT	customers	9	\N	{"phone": "0542502749", "last_name": "BACHIRI", "first_name": "NASSREDDINE"}	\N	154.242.183.125	2026-08-10 11:08:04.679651+02
100	2	INSERT	session_storm_entries	9	\N	\N	\N	154.242.183.125	2026-08-10 11:08:05.046344+02
101	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 11:11:26.840631+02
102	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 11:11:26.844042+02
103	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 11:11:26.87541+02
104	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 11:11:26.929817+02
105	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 11:11:26.954062+02
106	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 11:11:30.779372+02
107	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.183.125	2026-08-10 11:13:40.418809+02
108	3	LOGIN	\N	\N	\N	\N	User "fatiha_sobha" logged in	\N	2026-08-10 11:13:49.660582+02
109	3	SESSION_OPEN	cashier_sessions	3	\N	{"store_id": 1, "cashier_id": 3, "opening_cash": 16215}	\N	154.242.183.125	2026-08-10 11:13:53.566554+02
151	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.118809+02
110	3	INSERT	customers	10	\N	{"phone": "0564173649", "last_name": "AFFOU", "first_name": "KARIM"}	\N	154.242.183.125	2026-08-10 11:29:20.058097+02
111	3	INSERT	session_sim_sales	5	\N	{"offer_id": 20, "customer_id": 10}	\N	154.242.183.125	2026-08-10 11:29:28.993462+02
112	3	INSERT	customers	11	\N	{"phone": "0541761222", "last_name": "mezdek", "first_name": "Fatiha"}	\N	154.242.183.125	2026-08-10 11:34:00.928465+02
113	3	INSERT	session_storm_entries	10	\N	\N	\N	154.242.183.125	2026-08-10 11:34:01.216768+02
114	3	INSERT	customers	12	\N	{"phone": "0551334899", "last_name": "sahil", "first_name": "fares"}	\N	154.242.183.125	2026-08-10 11:45:09.772697+02
115	3	INSERT	session_storm_entries	11	\N	\N	\N	154.242.183.125	2026-08-10 11:45:10.060931+02
116	3	INSERT	customers	13	\N	{"phone": "0564164152", "last_name": "M guebbel", "first_name": "Mohammed"}	\N	154.242.183.125	2026-08-10 12:05:12.091521+02
117	3	INSERT	session_sim_sales	6	\N	{"offer_id": 20, "customer_id": 13}	\N	154.242.183.125	2026-08-10 12:05:21.152391+02
118	1	UPDATE	customers	13	{"id": 13, "notes": null, "address": "bocca ouled salem", "last_name": "M guebbel", "created_at": "2026-08-10T10:05:12.049Z", "created_by": 3, "first_name": "Mohammed", "profession": "travailier jour", "updated_at": "2026-08-10T10:05:12.049Z", "phone_number": "0564164152"}	{"notes": null, "address": "bocca ouled salem", "last_name": "M guebbel", "first_name": "Mohammed", "profession": "Travaillier Journallier", "phone_number": "0564164152"}	\N	154.242.183.125	2026-08-10 12:07:30.111461+02
119	1	UPDATE	customers	12	{"id": 12, "notes": null, "address": "hey zaouya", "last_name": "sahil", "created_at": "2026-08-10T09:45:09.741Z", "created_by": 3, "first_name": "fares", "profession": "etudient", "updated_at": "2026-08-10T09:45:09.741Z", "phone_number": "0551334899"}	{"notes": null, "address": "hey zaouya", "last_name": "sahil", "first_name": "fares", "profession": "student", "phone_number": "0551334899"}	\N	154.242.183.125	2026-08-10 12:08:09.146076+02
120	3	INSERT	customers	14	\N	{"phone": "0564176668", "last_name": "Hadj-Mostefa", "first_name": "Hocine"}	\N	154.242.183.125	2026-08-10 12:16:55.136843+02
121	3	INSERT	session_sim_sales	7	\N	{"offer_id": 20, "customer_id": 14}	\N	154.242.183.125	2026-08-10 12:17:02.308163+02
122	3	INSERT	customers	15	\N	{"phone": "0557772076", "last_name": "hamid", "first_name": "salem"}	\N	154.242.183.125	2026-08-10 12:20:08.10125+02
123	3	INSERT	session_storm_entries	12	\N	\N	\N	154.242.183.125	2026-08-10 12:20:08.569054+02
124	3	INSERT	customers	16	\N	{"phone": "0564184724", "last_name": "Hadj elezaar", "first_name": "Fatiha"}	\N	154.242.183.125	2026-08-10 12:24:59.454937+02
125	3	INSERT	session_sim_sales	8	\N	{"offer_id": 7, "customer_id": 16}	\N	154.242.183.125	2026-08-10 12:25:07.702557+02
126	3	INSERT	customers	17	\N	{"phone": "0540218996", "last_name": "letrach", "first_name": "moussa"}	\N	154.242.183.125	2026-08-10 12:38:46.480622+02
127	3	INSERT	session_storm_entries	13	\N	\N	\N	154.242.183.125	2026-08-10 12:38:46.7848+02
128	3	INSERT	customers	18	\N	{"phone": "0558411398", "last_name": "benbrik", "first_name": "rachid"}	\N	154.242.183.125	2026-08-10 12:48:15.374557+02
129	3	INSERT	session_storm_entries	14	\N	\N	\N	154.242.183.125	2026-08-10 12:48:15.838143+02
130	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.020939+02
131	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.025249+02
132	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.031411+02
133	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.039597+02
135	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.073533+02
134	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.072832+02
136	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.074973+02
137	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.079767+02
138	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.08859+02
139	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.090202+02
140	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 12:49:00.098206+02
141	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 12:49:11.405192+02
142	1	UPDATE	customers	17	{"id": 17, "notes": null, "address": "bocca ouled fetti", "last_name": "letrach", "created_at": "2026-08-10T10:38:46.425Z", "created_by": 3, "first_name": "moussa", "profession": "travaillier", "updated_at": "2026-08-10T10:38:46.425Z", "phone_number": "0540218996"}	{"notes": null, "address": "bocca ouled fetti", "last_name": "letrach", "first_name": "moussa", "profession": "Traivieur Journallier", "phone_number": "0540218996"}	\N	154.242.183.125	2026-08-10 12:50:31.113775+02
143	1	UPDATE	customers	17	{"id": 17, "notes": null, "address": "bocca ouled fetti", "last_name": "letrach", "created_at": "2026-08-10T10:38:46.425Z", "created_by": 3, "first_name": "moussa", "profession": "Traivieur Journallier", "updated_at": "2026-08-10T10:50:31.106Z", "phone_number": "0540218996"}	{"notes": null, "address": "bocca ouled fetti", "last_name": "Letrach", "first_name": "Moussa", "profession": "Traivieur Journallier", "phone_number": "0540218996"}	\N	154.242.183.125	2026-08-10 12:50:57.164852+02
144	1	UPDATE	customers	15	{"id": 15, "notes": null, "address": "sobha center", "last_name": "hamid", "created_at": "2026-08-10T10:20:08.080Z", "created_by": 3, "first_name": "salem", "profession": "travailier", "updated_at": "2026-08-10T10:20:08.080Z", "phone_number": "0557772076"}	{"notes": null, "address": "sobha center", "last_name": "Hamid", "first_name": "Salem", "profession": "travailier", "phone_number": "0557772076"}	\N	154.242.183.125	2026-08-10 12:51:19.886436+02
145	1	UPDATE	customers	18	{"id": 18, "notes": null, "address": "sobha", "last_name": "benbrik", "created_at": "2026-08-10T10:48:15.337Z", "created_by": 3, "first_name": "rachid", "profession": "student", "updated_at": "2026-08-10T10:48:15.337Z", "phone_number": "0558411398"}	{"notes": null, "address": "sobha", "last_name": "Benbrik", "first_name": "Rachid", "profession": "student", "phone_number": "0558411398"}	\N	154.242.183.125	2026-08-10 12:51:43.31677+02
146	1	UPDATE	customers	12	{"id": 12, "notes": null, "address": "hey zaouya", "last_name": "sahil", "created_at": "2026-08-10T09:45:09.741Z", "created_by": 3, "first_name": "fares", "profession": "student", "updated_at": "2026-08-10T10:08:09.142Z", "phone_number": "0551334899"}	{"notes": null, "address": "hey zaouya", "last_name": "Sahil", "first_name": "Fares", "profession": "student", "phone_number": "0551334899"}	\N	154.242.183.125	2026-08-10 12:52:01.459796+02
147	3	INSERT	customers	19	\N	{"phone": "050000", "last_name": "Meddah", "first_name": "Mohammed"}	\N	154.242.183.125	2026-08-10 14:08:57.969835+02
148	3	INSERT	session_storm_entries	15	\N	\N	\N	154.242.183.125	2026-08-10 14:08:58.372071+02
149	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.02077+02
150	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.108607+02
152	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.15052+02
153	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.163697+02
154	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.178562+02
155	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.186105+02
156	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.189981+02
157	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.208207+02
158	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 14:29:16.223454+02
159	3	INSERT	customers	20	\N	{"phone": "0550942244", "last_name": "Hamadi", "first_name": "Mohammed"}	\N	154.242.183.125	2026-08-10 14:36:22.176593+02
160	3	INSERT	session_storm_entries	16	\N	\N	\N	154.242.183.125	2026-08-10 14:36:22.550282+02
161	3	INSERT	customers	21	\N	{"phone": "0554137333", "last_name": "Khelifa zoubir", "first_name": "Fethi"}	\N	154.242.183.125	2026-08-10 14:41:19.405619+02
162	3	INSERT	session_storm_entries	17	\N	\N	\N	154.242.183.125	2026-08-10 14:41:19.821897+02
163	3	INSERT	customers	22	\N	{"phone": "0550410322", "last_name": "CC", "first_name": "Client"}	\N	154.242.183.125	2026-08-10 14:55:21.777722+02
164	3	INSERT	session_storm_entries	18	\N	\N	\N	154.242.183.125	2026-08-10 14:55:22.22723+02
165	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 15:27:17.462212+02
166	3	INSERT	customers	23	\N	{"phone": "0564195166", "last_name": "Yahiaoui", "first_name": "Mostafa"}	\N	154.242.186.73	2026-08-10 15:58:35.561525+02
167	3	INSERT	session_sim_sales	9	\N	{"offer_id": 20, "customer_id": 23}	\N	154.242.186.73	2026-08-10 15:58:42.779928+02
168	1	UPDATE	customers	23	{"id": 23, "notes": null, "address": "bocca ouled jilali", "last_name": "Yahiaoui", "created_at": "2026-08-10T13:58:35.491Z", "created_by": 3, "first_name": "Mostafa", "profession": "travaieur", "updated_at": "2026-08-10T13:58:35.491Z", "phone_number": "0564195166"}	{"notes": null, "address": "bocca ouled jilali", "last_name": "Yahiaoui", "first_name": "Mostafa", "profession": "Travaillier Journallier", "phone_number": "0564195166"}	\N	154.242.186.73	2026-08-10 16:04:35.604233+02
169	1	UPDATE	customers	19	{"id": 19, "notes": null, "address": "bocca amalssa", "last_name": "Meddah", "created_at": "2026-08-10T12:08:57.934Z", "created_by": 3, "first_name": "Mohammed", "profession": "tra", "updated_at": "2026-08-10T12:08:57.934Z", "phone_number": "050000"}	{"notes": null, "address": "bocca amalssa", "last_name": "Meddah", "first_name": "Mohammed", "profession": "Travaillier Journallier", "phone_number": "050000"}	\N	154.242.186.73	2026-08-10 16:05:16.643122+02
170	1	UPDATE	customers	20	{"id": 20, "notes": null, "address": "bocca ouled hamadi", "last_name": "Hamadi", "created_at": "2026-08-10T12:36:22.130Z", "created_by": 3, "first_name": "Mohammed", "profession": "trav", "updated_at": "2026-08-10T12:36:22.130Z", "phone_number": "0550942244"}	{"notes": null, "address": "bocca ouled hamadi", "last_name": "Hamadi", "first_name": "Mohammed", "profession": "Travaillier Journallier", "phone_number": "0550942244"}	\N	154.242.186.73	2026-08-10 16:05:33.402056+02
171	1	UPDATE	customers	15	{"id": 15, "notes": null, "address": "sobha center", "last_name": "Hamid", "created_at": "2026-08-10T10:20:08.080Z", "created_by": 3, "first_name": "Salem", "profession": "travailier", "updated_at": "2026-08-10T10:51:19.885Z", "phone_number": "0557772076"}	{"notes": null, "address": "sobha center", "last_name": "Hamid", "first_name": "Salem", "profession": "Travaillier Journallier", "phone_number": "0557772076"}	\N	154.242.186.73	2026-08-10 16:05:51.946745+02
172	1	UPDATE	customers	14	{"id": 14, "notes": null, "address": "hey ouled mostefa", "last_name": "Hadj-Mostefa", "created_at": "2026-08-10T10:16:55.118Z", "created_by": 3, "first_name": "Hocine", "profession": "travailier", "updated_at": "2026-08-10T10:16:55.118Z", "phone_number": "0564176668"}	{"notes": null, "address": "hey ouled mostefa", "last_name": "Hadj-Mostefa", "first_name": "Hocine", "profession": "Travaillier Journallier", "phone_number": "0564176668"}	\N	154.242.186.73	2026-08-10 16:06:26.588598+02
173	3	INSERT	customers	24	\N	{"phone": "0542875350", "last_name": "benhenni", "first_name": "Bou abedlla"}	\N	154.242.186.73	2026-08-10 17:24:47.101447+02
174	3	INSERT	session_storm_entries	19	\N	\N	\N	154.242.186.73	2026-08-10 17:24:47.422469+02
175	3	INSERT	customers	25	\N	{"phone": "05000000", "last_name": "Ooredoo", "first_name": "client"}	\N	154.242.186.73	2026-08-10 17:30:39.752117+02
176	3	INSERT	session_storm_entries	20	\N	\N	\N	154.242.186.73	2026-08-10 17:30:40.073836+02
177	3	INSERT	customers	26	\N	{"phone": "0564170247", "last_name": "Benbrik", "first_name": "Fatiha"}	\N	154.242.186.73	2026-08-10 17:40:56.604531+02
178	3	INSERT	session_sim_sales	10	\N	{"offer_id": 20, "customer_id": 26}	\N	154.242.186.73	2026-08-10 17:41:03.179101+02
179	3	INSERT	customers	27	\N	{"phone": "0564682822", "last_name": "Laameche", "first_name": "Abdelkadir"}	\N	154.242.186.73	2026-08-10 17:45:37.68245+02
180	3	INSERT	session_storm_entries	21	\N	\N	\N	154.242.186.73	2026-08-10 17:45:38.004382+02
181	3	INSERT	customers	28	\N	{"phone": "050000000", "last_name": "Ooredoo", "first_name": "Client"}	\N	154.242.186.73	2026-08-10 18:25:53.28025+02
182	3	INSERT	session_storm_entries	22	\N	\N	\N	154.242.186.73	2026-08-10 18:25:53.726318+02
183	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 19:15:46.789741+02
184	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 19:15:46.842211+02
185	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 19:15:46.869325+02
186	3	LOGIN	\N	\N	\N	\N	User "fatiha_sobha" logged in	\N	2026-08-10 19:15:51.474264+02
187	3	INSERT	customers	29	\N	{"phone": "0564173278", "last_name": "Cherbal", "first_name": "Houria"}	\N	154.242.186.73	2026-08-10 19:16:40.631656+02
188	3	INSERT	session_sim_sales	11	\N	{"offer_id": 20, "customer_id": 29}	\N	154.242.186.73	2026-08-10 19:16:45.35926+02
189	3	INSERT	session_storm_entries	23	\N	\N	\N	154.242.186.73	2026-08-10 19:25:39.31637+02
190	3	SESSION_CLOSE	cashier_sessions	3	\N	\N	\N	154.242.186.73	2026-08-10 19:25:56.86895+02
191	3	LOGOUT	\N	\N	\N	\N	User "fatiha_sobha" logged out	154.242.186.73	2026-08-10 19:26:01.531193+02
192	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-10 19:26:05.45824+02
193	1	LOGOUT	\N	\N	\N	\N	User "admin" logged out	154.242.186.73	2026-08-10 19:35:48.064634+02
194	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 19:35:50.475812+02
195	2	INSERT	session_storm_entries	24	\N	\N	\N	154.242.186.73	2026-08-10 19:49:44.729993+02
196	2	INSERT	session_storm_entries	25	\N	\N	\N	154.242.186.73	2026-08-10 19:50:55.240723+02
197	2	INSERT	customers	30	\N	{"phone": "0564175556", "last_name": "Menaouta", "first_name": "Adem"}	\N	154.242.186.73	2026-08-10 19:55:52.988245+02
198	2	INSERT	session_sim_sales	12	\N	{"offer_id": 20, "customer_id": 30}	\N	154.242.186.73	2026-08-10 19:55:59.167344+02
199	2	INSERT	session_storm_entries	26	\N	\N	\N	154.242.186.73	2026-08-10 19:59:02.443592+02
200	2	INSERT	session_storm_entries	27	\N	\N	\N	154.242.186.73	2026-08-10 20:08:50.43029+02
201	2	INSERT	session_sim_sales	13	\N	{"offer_id": 16, "customer_id": 1}	\N	154.242.186.73	2026-08-10 20:14:43.522315+02
202	2	INSERT	session_sim_sales	14	\N	{"offer_id": 7, "customer_id": 1}	\N	154.242.186.73	2026-08-10 20:18:34.276009+02
203	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:26:17.004271+02
204	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:26:17.008372+02
205	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:26:17.039497+02
206	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:26:17.040852+02
207	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:26:17.046831+02
208	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-10 20:26:20.813885+02
209	2	INSERT	session_storm_entries	28	\N	\N	\N	154.242.186.73	2026-08-10 20:30:10.420742+02
210	2	INSERT	session_storm_entries	29	\N	\N	\N	154.242.186.73	2026-08-10 20:42:02.344341+02
211	3	LOGIN	\N	\N	\N	\N	User "fatiha_sobha" logged in	\N	2026-08-10 20:43:28.290652+02
212	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:44:17.68595+02
213	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:44:17.79879+02
214	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 20:44:17.801182+02
215	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 20:44:22.37992+02
216	3	LOGOUT	\N	\N	\N	\N	User "fatiha_sobha" logged out	154.242.186.73	2026-08-10 20:45:31.822008+02
217	2	INSERT	session_sim_sales	15	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.186.73	2026-08-10 21:16:08.909608+02
218	2	INSERT	session_sim_sales	16	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.186.73	2026-08-10 21:55:28.596749+02
220	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.052036+02
221	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.061964+02
222	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.067326+02
219	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.05056+02
223	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.091137+02
224	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.094163+02
226	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.157182+02
227	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.167774+02
225	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 22:58:00.150457+02
228	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-10 22:58:04.054592+02
229	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 23:00:09.057907+02
230	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 23:00:09.072835+02
231	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-10 23:00:09.089555+02
232	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-10 23:00:12.869415+02
233	2	SESSION_CLOSE	cashier_sessions	2	\N	\N	\N	154.242.186.73	2026-08-10 23:03:11.182997+02
234	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.186.73	2026-08-10 23:03:21.757467+02
235	1	REPORT_GENERATE	daily_reports	1	\N	{"date": "2026-08-10", "store_id": 1, "gross_profit": 7574.5, "total_revenue": 49980}	\N	154.242.186.73	2026-08-10 23:12:55.755889+02
236	1	LOGOUT	\N	\N	\N	\N	User "admin" logged out	154.242.186.73	2026-08-10 23:18:37.159187+02
237	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-11 09:15:39.811274+02
238	2	SESSION_OPEN	cashier_sessions	4	\N	{"store_id": 1, "cashier_id": 2, "opening_cash": 0}	\N	154.242.186.73	2026-08-11 09:15:42.977313+02
239	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 09:15:59.728087+02
240	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 09:18:08.30173+02
241	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 09:19:55.489831+02
242	5	SESSION_OPEN	cashier_sessions	5	\N	{"store_id": 2, "cashier_id": 5, "opening_cash": 0}	\N	105.235.139.207	2026-08-11 09:21:30.631602+02
243	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 09:40:35.029385+02
244	5	INSERT	session_storm_entries	30	\N	\N	\N	105.235.139.207	2026-08-11 09:44:57.04084+02
245	2	INSERT	session_storm_entries	31	\N	\N	\N	154.242.186.73	2026-08-11 09:48:09.377564+02
246	2	INSERT	session_storm_entries	32	\N	\N	\N	154.242.186.73	2026-08-11 09:53:13.750024+02
247	5	INSERT	session_sim_sales	17	\N	{"offer_id": 20, "customer_id": 1}	\N	105.235.139.207	2026-08-11 09:59:41.847405+02
248	5	INSERT	session_sim_sales	18	\N	{"offer_id": 20, "customer_id": 1}	\N	105.235.139.207	2026-08-11 10:00:07.520318+02
249	2	INSERT	session_storm_entries	33	\N	\N	\N	154.242.186.73	2026-08-11 10:05:56.534223+02
250	5	INSERT	session_sim_sales	19	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.139.207	2026-08-11 10:07:23.332048+02
251	2	INSERT	session_storm_entries	34	\N	\N	\N	154.242.186.73	2026-08-11 10:10:04.090668+02
252	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:18:50.17701+02
253	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:18:50.226121+02
254	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 10:18:55.240548+02
255	5	INSERT	session_storm_entries	35	\N	\N	\N	105.235.138.133	2026-08-11 10:22:16.714093+02
256	5	INSERT	session_sim_sales	20	\N	{"offer_id": 20, "customer_id": 1}	\N	105.235.138.133	2026-08-11 10:31:54.092055+02
257	2	INSERT	session_sim_sales	21	\N	{"offer_id": 16, "customer_id": 1}	\N	154.242.186.73	2026-08-11 10:39:13.853283+02
258	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.606014+02
259	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.624463+02
260	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.658431+02
261	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.667495+02
262	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.673326+02
263	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.68249+02
264	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.688641+02
265	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.693344+02
266	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:40:54.731529+02
267	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 10:40:58.170957+02
268	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:42:41.055134+02
269	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:42:41.056549+02
270	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:42:41.064482+02
271	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:42:41.069829+02
272	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 10:42:41.083423+02
273	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 10:43:06.635567+02
274	5	INSERT	session_storm_entries	36	\N	\N	\N	105.235.138.133	2026-08-11 10:43:22.582651+02
275	2	INSERT	session_storm_entries	37	\N	\N	\N	154.242.186.73	2026-08-11 10:51:56.431538+02
276	2	INSERT	session_storm_entries	38	\N	\N	\N	154.242.186.73	2026-08-11 10:58:56.198508+02
277	2	INSERT	session_sim_sales	22	\N	{"offer_id": 16, "customer_id": 1}	\N	154.242.186.73	2026-08-11 10:59:44.262948+02
278	5	INSERT	session_sim_sales	23	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 11:02:24.13207+02
279	5	INSERT	session_sim_sales	24	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 11:02:39.45729+02
280	5	INSERT	session_sim_sales	25	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 11:02:55.517731+02
281	2	INSERT	session_storm_entries	39	\N	\N	\N	154.242.186.73	2026-08-11 11:06:19.567699+02
282	5	INSERT	session_storm_entries	40	\N	\N	\N	105.235.138.133	2026-08-11 11:08:18.073117+02
283	2	INSERT	session_storm_entries	41	\N	\N	\N	154.242.186.73	2026-08-11 11:12:57.511483+02
284	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 11:19:11.702997+02
285	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.186.73	2026-08-11 11:23:46.628708+02
286	3	LOGIN	\N	\N	\N	\N	User "fatiha_sobha" logged in	\N	2026-08-11 11:23:49.8234+02
287	3	SESSION_OPEN	cashier_sessions	6	\N	{"store_id": 1, "cashier_id": 3, "opening_cash": 10594}	\N	154.242.186.73	2026-08-11 11:23:52.397353+02
288	3	INSERT	customers	31	\N	{"phone": "0559379917", "last_name": "0000", "first_name": "00000"}	\N	154.242.186.73	2026-08-11 11:27:32.2071+02
289	3	INSERT	session_storm_entries	42	\N	\N	\N	154.242.186.73	2026-08-11 11:27:32.565768+02
290	3	INSERT	session_sim_sales	26	\N	{"offer_id": 18, "customer_id": 1}	\N	154.242.186.73	2026-08-11 11:34:59.084477+02
291	3	INSERT	session_storm_entries	43	\N	\N	\N	154.242.186.73	2026-08-11 11:36:41.933745+02
292	3	INSERT	session_storm_entries	44	\N	\N	\N	154.242.186.73	2026-08-11 11:37:43.592849+02
293	3	INSERT	customers	32	\N	{"phone": "0558704129", "last_name": "0", "first_name": "000"}	\N	154.242.186.73	2026-08-11 11:39:42.700398+02
294	3	INSERT	session_storm_entries	45	\N	\N	\N	154.242.186.73	2026-08-11 11:39:43.013164+02
295	3	INSERT	customers	33	\N	{"phone": "0552284283", "last_name": "boukhobza", "first_name": "chaimaa"}	\N	154.242.186.73	2026-08-11 11:41:15.797357+02
296	3	INSERT	session_storm_entries	46	\N	\N	\N	154.242.186.73	2026-08-11 11:41:16.111771+02
297	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 11:43:24.207281+02
298	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 11:43:24.211411+02
299	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 11:43:24.256464+02
300	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 11:43:24.262651+02
301	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 11:43:24.281552+02
302	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 11:43:39.745481+02
303	5	INSERT	session_sim_sales	27	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 11:44:01.626788+02
304	3	INSERT	session_storm_entries	47	\N	\N	\N	154.242.186.73	2026-08-11 11:54:16.255843+02
305	3	INSERT	session_storm_entries	48	\N	\N	\N	154.242.186.73	2026-08-11 11:54:25.776726+02
306	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 11:55:45.299176+02
307	3	INSERT	session_storm_entries	49	\N	\N	\N	154.242.186.73	2026-08-11 11:56:34.115889+02
308	3	INSERT	customers	34	\N	{"phone": "0541297855", "last_name": "00", "first_name": "00"}	\N	154.242.186.73	2026-08-11 12:03:19.81723+02
309	3	INSERT	session_storm_entries	50	\N	\N	\N	154.242.186.73	2026-08-11 12:03:20.145435+02
310	3	INSERT	customers	35	\N	{"phone": "0555054785", "last_name": "0", "first_name": "0"}	\N	154.242.186.73	2026-08-11 12:05:04.590305+02
311	3	INSERT	session_storm_entries	51	\N	\N	\N	154.242.186.73	2026-08-11 12:05:04.901283+02
312	5	INSERT	session_storm_entries	52	\N	\N	\N	105.235.138.133	2026-08-11 12:16:39.405599+02
313	5	INSERT	session_sim_sales	28	\N	{"offer_id": 18, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:17:02.98364+02
314	5	INSERT	session_sim_sales	29	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:17:20.671573+02
315	5	INSERT	session_sim_sales	30	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:17:39.436962+02
316	3	INSERT	customers	36	\N	{"phone": "0559184224", "last_name": "baydor", "first_name": "amin"}	\N	154.242.186.73	2026-08-11 12:32:36.935585+02
317	3	INSERT	session_storm_entries	53	\N	\N	\N	154.242.186.73	2026-08-11 12:32:37.254221+02
318	3	INSERT	customers	37	\N	{"phone": "0564109130", "last_name": "Chaib eddour", "first_name": "Benyahia"}	\N	154.242.186.73	2026-08-11 12:37:19.149882+02
319	3	INSERT	session_sim_sales	31	\N	{"offer_id": 20, "customer_id": 37}	\N	154.242.186.73	2026-08-11 12:37:40.713653+02
320	5	INSERT	session_sim_sales	32	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:40:33.13657+02
321	5	INSERT	session_sim_sales	33	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:40:49.683629+02
322	5	INSERT	session_sim_sales	34	\N	{"offer_id": 7, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:41:03.093756+02
323	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:49.987084+02
324	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:49.997809+02
325	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.001423+02
326	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.013735+02
327	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.022133+02
328	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.028123+02
329	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.035193+02
330	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.058204+02
331	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.066978+02
332	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.092688+02
333	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.094779+02
334	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.100813+02
335	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.102702+02
336	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:47:50.104601+02
337	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 12:47:52.841223+02
338	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:49:01.55994+02
339	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:49:01.565431+02
340	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:49:01.566406+02
341	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:49:01.627992+02
342	5	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:49:01.772709+02
343	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 12:49:15.969722+02
344	5	INSERT	session_sim_sales	35	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:49:33.696316+02
345	5	INSERT	session_sim_sales	36	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 12:53:43.130425+02
346	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 12:56:11.892061+02
347	3	INSERT	customers	38	\N	{"phone": "0564112113", "last_name": "Mokhfi", "first_name": "Roufaida"}	\N	154.242.186.73	2026-08-11 12:58:25.141474+02
348	3	INSERT	session_sim_sales	37	\N	{"offer_id": 20, "customer_id": 38}	\N	154.242.186.73	2026-08-11 12:59:06.542607+02
349	5	INSERT	session_storm_entries	54	\N	\N	\N	105.235.138.133	2026-08-11 13:06:59.140932+02
350	5	INSERT	session_storm_entries	55	\N	\N	\N	105.235.138.133	2026-08-11 13:12:47.681103+02
351	3	INSERT	customers	39	\N	{"phone": "0564109214", "last_name": "Benaama", "first_name": "Samir"}	\N	154.242.186.73	2026-08-11 13:16:32.376641+02
352	3	INSERT	session_sim_sales	38	\N	{"offer_id": 20, "customer_id": 39}	\N	154.242.186.73	2026-08-11 13:16:41.746528+02
353	3	INSERT	customers	40	\N	{"phone": "0555775287", "last_name": "daheman", "first_name": "Rayene"}	\N	154.242.186.73	2026-08-11 13:20:33.714546+02
354	3	INSERT	session_storm_entries	56	\N	\N	\N	154.242.186.73	2026-08-11 13:20:34.080262+02
355	5	INSERT	session_storm_entries	57	\N	\N	\N	105.235.138.133	2026-08-11 13:44:25.962993+02
356	3	INSERT	customers	41	\N	{"phone": "0551889569", "last_name": "0", "first_name": "0"}	\N	154.242.186.73	2026-08-11 13:48:56.711056+02
357	3	INSERT	session_storm_entries	58	\N	\N	\N	154.242.186.73	2026-08-11 13:48:57.018245+02
358	3	INSERT	customers	42	\N	{"phone": "0558774111", "last_name": "0", "first_name": "0"}	\N	154.242.186.73	2026-08-11 13:49:44.342877+02
359	3	INSERT	session_storm_entries	59	\N	\N	\N	154.242.186.73	2026-08-11 13:49:44.64928+02
360	3	INSERT	customers	43	\N	{"phone": "0551354082", "last_name": "0", "first_name": "0"}	\N	154.242.186.73	2026-08-11 13:54:54.530895+02
361	3	INSERT	session_storm_entries	60	\N	\N	\N	154.242.186.73	2026-08-11 13:54:54.860302+02
362	3	INSERT	customers	44	\N	{"phone": "0550433799", "last_name": "Aissaoui", "first_name": "Abdel hamid"}	\N	154.242.186.73	2026-08-11 14:03:01.97036+02
363	3	INSERT	session_sim_sales	39	\N	{"offer_id": 27, "customer_id": 44}	\N	154.242.186.73	2026-08-11 14:03:07.465603+02
364	3	INSERT	customers	45	\N	{"phone": "0000050", "last_name": "0", "first_name": "0"}	\N	154.242.186.73	2026-08-11 14:07:19.686192+02
365	3	INSERT	session_storm_entries	61	\N	\N	\N	154.242.186.73	2026-08-11 14:07:20.010889+02
366	5	INSERT	session_sim_sales	40	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.133	2026-08-11 14:29:21.589003+02
367	5	INSERT	session_sim_sales	41	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.138.140	2026-08-11 15:37:34.022574+02
368	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 15:42:13.171216+02
369	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 15:42:13.189614+02
370	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 15:42:13.194949+02
371	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 15:42:13.198236+02
372	3	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 15:42:13.21376+02
373	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 16:02:48.903835+02
374	4	SESSION_OPEN	cashier_sessions	7	\N	{"store_id": 2, "cashier_id": 4, "opening_cash": 29720}	\N	105.235.138.140	2026-08-11 16:02:57.051133+02
375	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 16:31:28.43613+02
376	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.780679+02
377	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.785324+02
378	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.786979+02
379	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.79377+02
380	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.79422+02
381	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.84314+02
382	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.847126+02
383	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.849528+02
384	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.850999+02
385	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.861106+02
386	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.862773+02
387	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.865622+02
388	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.869372+02
389	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.875369+02
390	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.889149+02
391	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 16:48:58.894065+02
392	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 16:49:01.930091+02
393	3	LOGIN	\N	\N	\N	\N	User "fatiha_sobha" logged in	\N	2026-08-11 17:17:53.078264+02
394	3	INSERT	customers	46	\N	{"phone": "0550543669", "last_name": "Belhadj benyahia", "first_name": "Abdelkadir"}	\N	154.242.184.80	2026-08-11 17:20:32.348355+02
395	3	INSERT	session_sim_sales	42	\N	{"offer_id": 27, "customer_id": 46}	\N	154.242.184.80	2026-08-11 17:20:54.734031+02
396	3	INSERT	customers	47	\N	{"phone": "0552962015", "last_name": "0", "first_name": "0"}	\N	154.242.184.80	2026-08-11 17:25:41.647198+02
397	3	INSERT	session_storm_entries	62	\N	\N	\N	154.242.184.80	2026-08-11 17:25:42.030877+02
398	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.246313+02
399	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.253953+02
400	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.261808+02
401	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.278899+02
402	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.285985+02
403	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.29495+02
404	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.309396+02
405	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.317666+02
406	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.322667+02
407	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.324799+02
408	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 17:50:14.327534+02
409	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 17:50:17.853616+02
410	3	INSERT	customers	48	\N	{"phone": "0564042794", "last_name": "Ali abbes", "first_name": "Fatima"}	\N	154.242.184.80	2026-08-11 18:38:05.225058+02
411	3	INSERT	session_sim_sales	43	\N	{"offer_id": 7, "customer_id": 48}	\N	154.242.184.80	2026-08-11 18:38:08.402658+02
412	3	INSERT	customers	49	\N	{"phone": "0564047237", "last_name": "0", "first_name": "0"}	\N	154.242.184.80	2026-08-11 18:39:37.093342+02
413	3	INSERT	session_storm_entries	63	\N	\N	\N	154.242.184.80	2026-08-11 18:39:37.433984+02
414	4	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 19:03:52.225682+02
415	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 19:04:04.899184+02
416	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 19:04:59.984089+02
417	4	INSERT	session_sim_sales	44	\N	{"offer_id": 7, "customer_id": 1}	\N	105.235.137.159	2026-08-11 19:05:18.604387+02
418	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 19:09:45.634772+02
419	3	INSERT	session_storm_entries	64	\N	\N	\N	154.242.184.80	2026-08-11 19:18:13.481316+02
420	3	VOID	session_storm_entries	64	{"session_id": 6}	\N	\N	154.242.184.80	2026-08-11 19:18:30.213903+02
421	3	INSERT	session_storm_entries	65	\N	\N	\N	154.242.184.80	2026-08-11 19:19:00.762496+02
422	3	INSERT	register_expenses	2	\N	{"amount": 44590, "category": "utility", "store_id": 1, "session_id": 6, "description": "This was taken for buying a new storm by the admin.", "expense_date": "2026-08-11"}	\N	154.242.184.80	2026-08-11 19:21:40.153949+02
423	3	UPDATE	store_register_state	112	{"cash_amount": 49119}	{"delta": -44590, "notes": "Register expense #2: This was taken for buying a new storm by the admin.", "expense_id": 2, "cash_amount": 4529}	Register expense #2 created	154.242.184.80	2026-08-11 19:21:40.153949+02
424	3	SESSION_CLOSE	cashier_sessions	6	\N	\N	\N	154.242.184.80	2026-08-11 19:25:41.803249+02
425	3	LOGOUT	\N	\N	\N	\N	User "fatiha_sobha" logged out	154.242.184.80	2026-08-11 19:25:43.412466+02
426	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-11 19:25:47.543854+02
427	2	INSERT	session_sim_sales	45	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 19:27:52.899097+02
428	2	INSERT	session_sim_sales	46	\N	{"offer_id": 18, "customer_id": 1}	\N	154.242.184.80	2026-08-11 19:28:03.228057+02
429	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 19:28:21.81566+02
430	2	INSERT	session_storm_entries	66	\N	\N	\N	154.242.184.80	2026-08-11 19:30:42.742894+02
431	2	INSERT	session_storm_entries	67	\N	\N	\N	154.242.184.80	2026-08-11 19:30:56.103954+02
432	2	INSERT	session_storm_entries	68	\N	\N	\N	154.242.184.80	2026-08-11 19:32:03.808929+02
433	2	INSERT	session_storm_entries	69	\N	\N	\N	154.242.184.80	2026-08-11 19:33:36.074056+02
434	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 19:42:16.372697+02
435	4	INSERT	session_sim_sales	47	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.137.159	2026-08-11 19:43:12.146764+02
436	4	INSERT	session_storm_entries	70	\N	\N	\N	105.235.137.159	2026-08-11 19:43:35.184875+02
437	4	INSERT	session_storm_entries	71	\N	\N	\N	105.235.137.159	2026-08-11 19:43:49.470672+02
438	4	INSERT	session_storm_entries	72	\N	\N	\N	105.235.137.159	2026-08-11 19:44:01.997793+02
439	2	INSERT	session_storm_entries	73	\N	\N	\N	154.242.184.80	2026-08-11 19:51:26.509372+02
440	2	INSERT	session_storm_entries	74	\N	\N	\N	154.242.184.80	2026-08-11 19:55:10.309578+02
441	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.184.80	2026-08-11 20:02:32.232316+02
442	5	LOGIN	\N	\N	\N	\N	User "hadil_ainmeraine" logged in	\N	2026-08-11 20:02:43.609084+02
443	5	SESSION_CLOSE	cashier_sessions	5	\N	\N	\N	154.242.184.80	2026-08-11 20:05:58.644099+02
444	5	LOGOUT	\N	\N	\N	\N	User "hadil_ainmeraine" logged out	154.242.184.80	2026-08-11 20:06:00.628396+02
445	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-11 20:06:03.207798+02
446	4	INSERT	session_storm_entries	75	\N	\N	\N	105.235.137.159	2026-08-11 20:07:26.906967+02
447	2	INSERT	session_sim_sales	48	\N	{"offer_id": 16, "customer_id": 1}	\N	154.242.184.80	2026-08-11 20:10:22.682481+02
448	2	VOID	session_sim_sales	48	{"session_id": 4}	\N	\N	154.242.184.80	2026-08-11 20:11:12.753727+02
449	2	INSERT	session_sim_sales	49	\N	{"offer_id": 16, "customer_id": 1}	\N	154.242.184.80	2026-08-11 20:11:25.127639+02
450	4	INSERT	session_storm_entries	76	\N	\N	\N	105.235.137.159	2026-08-11 20:18:27.753255+02
451	2	INSERT	session_storm_entries	77	\N	\N	\N	154.242.184.80	2026-08-11 20:24:17.038387+02
452	4	INSERT	session_sim_sales	50	\N	{"offer_id": 7, "customer_id": 1}	\N	105.235.137.159	2026-08-11 20:32:22.116422+02
453	4	INSERT	session_sim_sales	51	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.137.159	2026-08-11 20:37:58.717367+02
454	4	INSERT	session_storm_entries	78	\N	\N	\N	105.235.137.159	2026-08-11 20:40:38.92137+02
455	2	INSERT	session_sim_sales	52	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 20:43:45.536132+02
456	2	INSERT	session_storm_entries	79	\N	\N	\N	154.242.184.80	2026-08-11 20:49:56.648008+02
457	2	INSERT	session_storm_entries	80	\N	\N	\N	154.242.184.80	2026-08-11 20:53:37.027013+02
458	2	INSERT	session_sim_sales	53	\N	{"offer_id": 17, "customer_id": 1}	\N	154.242.184.80	2026-08-11 20:54:02.286456+02
459	2	INSERT	session_storm_entries	81	\N	\N	\N	154.242.184.80	2026-08-11 20:54:35.59312+02
460	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 21:11:57.432557+02
461	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-11 21:12:02.202618+02
462	2	INSERT	session_sim_sales	54	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 21:22:32.93168+02
463	2	INSERT	session_sim_sales	55	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 21:22:43.391487+02
464	2	INSERT	session_sim_sales	56	\N	{"offer_id": 7, "customer_id": 1}	\N	154.242.184.80	2026-08-11 21:23:51.386056+02
465	2	INSERT	session_storm_entries	82	\N	\N	\N	154.242.184.80	2026-08-11 21:25:03.210318+02
466	2	INSERT	session_storm_entries	83	\N	\N	\N	154.242.184.80	2026-08-11 21:49:13.502205+02
467	2	INSERT	session_storm_entries	84	\N	\N	\N	154.242.184.80	2026-08-11 22:11:27.101257+02
468	2	INSERT	session_sim_sales	57	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 22:30:35.610947+02
469	4	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 22:32:15.327551+02
470	4	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 22:32:15.328472+02
471	4	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 22:32:15.338099+02
472	4	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 22:32:15.350405+02
473	4	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-11 22:32:15.365002+02
474	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 22:32:22.146123+02
475	4	INSERT	session_sim_sales	58	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.137.159	2026-08-11 22:32:42.92364+02
476	4	INSERT	session_sim_sales	59	\N	{"offer_id": 16, "customer_id": 1}	\N	105.235.137.159	2026-08-11 22:35:56.584817+02
477	2	VOID	session_sim_sales	57	{"session_id": 4}	\N	\N	154.242.184.80	2026-08-11 22:42:47.152074+02
478	4	LOGIN	\N	\N	\N	\N	User "aziz_ainmeraine" logged in	\N	2026-08-11 22:45:54.414356+02
479	2	INSERT	session_sim_sales	60	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 22:47:30.30218+02
480	2	VOID	session_sim_sales	60	{"session_id": 4}	\N	\N	154.242.184.80	2026-08-11 22:47:50.424352+02
481	2	INSERT	session_sim_sales	61	\N	{"offer_id": 20, "customer_id": 1}	\N	154.242.184.80	2026-08-11 22:48:02.095131+02
482	2	SESSION_CLOSE	cashier_sessions	4	\N	\N	\N	154.242.184.80	2026-08-11 22:50:49.179972+02
483	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.184.80	2026-08-11 22:50:52.194576+02
484	4	VOID	session_storm_entries	72	{"session_id": 7}	\N	\N	154.242.184.80	2026-08-11 22:51:17.898354+02
485	4	SESSION_CLOSE	cashier_sessions	7	\N	\N	\N	154.242.184.80	2026-08-11 22:52:07.206754+02
486	4	LOGOUT	\N	\N	\N	\N	User "aziz_ainmeraine" logged out	154.242.184.80	2026-08-11 22:52:09.086746+02
487	1	REPORT_GENERATE	daily_reports	2	\N	{"date": "2026-08-11", "store_id": 1, "gross_profit": 6161.6, "total_revenue": 74464}	\N	154.242.184.80	2026-08-11 22:52:20.185672+02
488	1	REPORT_GENERATE	daily_reports	3	\N	{"date": "2026-08-11", "store_id": 2, "gross_profit": 1339.875, "total_revenue": 41795}	\N	154.242.184.80	2026-08-11 22:52:20.206468+02
489	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-23 18:35:40.259922+02
490	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 21:29:51.437939+02
491	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-23 21:30:04.57363+02
492	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.555819+02
493	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.560939+02
494	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.567602+02
495	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.580113+02
496	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.581677+02
497	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.627695+02
498	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.657402+02
499	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.676161+02
500	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.676987+02
501	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-23 23:14:42.71368+02
502	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 00:11:18.698016+02
503	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.305036+02
504	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.397971+02
505	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.39947+02
506	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.401298+02
507	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.409604+02
508	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.450328+02
509	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.466459+02
510	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.472642+02
511	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.475869+02
512	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.492076+02
513	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 02:11:07.502372+02
514	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 18:08:05.061932+02
515	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 19:07:25.3766+02
516	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 19:40:03.087798+02
517	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-24 20:02:44.572034+02
518	2	SESSION_OPEN	cashier_sessions	8	\N	{"store_id": 1, "cashier_id": 2, "opening_cash": 0}	\N	154.242.182.234	2026-08-24 20:02:46.826063+02
519	2	INSERT	session_storm_entries	85	\N	\N	\N	154.242.182.234	2026-08-24 20:03:03.527196+02
520	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 20:17:21.493531+02
521	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 20:17:24.566284+02
522	2	INSERT	session_storm_entries	86	\N	\N	\N	154.242.182.234	2026-08-24 20:18:47.471191+02
523	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 20:58:40.494636+02
524	1	LOGOUT	\N	\N	\N	\N	User "admin" logged out	154.242.182.234	2026-08-24 20:58:46.540717+02
525	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-24 20:58:55.482525+02
526	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 20:59:52.847197+02
527	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 21:03:47.95178+02
528	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 21:04:10.662295+02
529	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 21:04:23.388644+02
530	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 21:15:13.754263+02
531	1	UPDATE	products	1	{"id": 1, "name": "Samsung Galaxy A56 5G 8/128", "price": 55000, "points": 0, "barcode": "125060", "is_active": true, "created_at": "2026-08-09T19:59:46.694Z", "real_price": 53000, "sort_order": 0, "updated_at": "2026-08-09T19:59:46.694Z", "category_id": 6, "commission_amount": 0, "low_stock_threshold": 5}	{"name": "Samsung Galaxy A56 5G 8/128", "price": 55000, "points": 100, "barcode": "125060", "real_price": 53000, "category_id": 6, "commission_amount": 0, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 21:44:53.890622+02
532	2	INSERT	customers	50	\N	{"phone": "0559516395", "last_name": "Hamidi", "first_name": "Aymen"}	\N	154.242.182.234	2026-08-24 21:45:25.91671+02
533	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.027413+02
534	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.039207+02
535	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.059177+02
536	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.096835+02
537	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.212288+02
538	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.213813+02
539	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.219715+02
540	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.245538+02
541	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:26:37.254696+02
542	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-24 22:26:41.202212+02
543	1	UPDATE	offers	17	{"id": 17, "name": "La Gold 1000", "points": 250, "is_active": true, "created_at": "2026-08-09T19:32:43.026Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-09T19:33:44.043Z", "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	{"name": "La Gold 1000", "real_price": 1000, "sort_order": 0, "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:28:11.629339+02
544	1	UPDATE	offers	17	{"id": 17, "name": "La Gold 1000", "points": 250, "is_active": true, "created_at": "2026-08-09T19:32:43.026Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-24T20:28:11.624Z", "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	{"name": "La Gold 1000", "real_price": 1000, "sort_order": 0, "category_id": 1, "selling_price": 1000, "commission_amount": 50, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:28:22.429514+02
545	1	INSERT	offer_categories	7	\N	{"id": 7, "name": "test", "is_active": true, "sort_order": 0}	\N	154.242.182.234	2026-08-24 22:29:38.479428+02
546	1	DELETE	offer_categories	7	\N	{"is_active": false}	\N	154.242.182.234	2026-08-24 22:29:41.954175+02
547	1	UPDATE	offer_categories	7	\N	\N	Restored previously deleted category during new creation attempt.	154.242.182.234	2026-08-24 22:30:21.229749+02
548	1	INSERT	offers	30	\N	{"id": 30, "name": "test", "points": 0, "is_active": true, "created_at": "2026-08-24T20:30:24.627Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-24T20:30:24.627Z", "category_id": 7, "selling_price": 1000, "commission_amount": 0, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:30:24.639814+02
549	1	DELETE	offers	30	\N	{"is_active": false}	\N	154.242.182.234	2026-08-24 22:34:42.096079+02
550	1	UPDATE	offers	17	{"id": 17, "name": "La Gold 1000", "is_active": true, "created_at": "2026-08-09T19:32:43.026Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-24T20:28:22.420Z", "category_id": 1, "selling_price": 1000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 250, "low_stock_threshold": 5}	{"name": "La Gold 1000", "real_price": 1000, "sort_order": 0, "category_id": 1, "selling_price": 1000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 250, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:42:54.086134+02
551	1	UPDATE	offers	18	{"id": 18, "name": "La Gold 1500", "is_active": true, "created_at": "2026-08-09T19:32:53.921Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:33:50.776Z", "category_id": 1, "selling_price": 1500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 375, "low_stock_threshold": 5}	{"name": "La Gold 1500", "real_price": 1500, "sort_order": 0, "category_id": 1, "selling_price": 1500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 375, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:03.68981+02
552	1	UPDATE	offers	19	{"id": 19, "name": "La Gold 2000", "is_active": true, "created_at": "2026-08-09T19:33:15.933Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:33:15.933Z", "category_id": 1, "selling_price": 2000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 500, "low_stock_threshold": 5}	{"name": "La Gold 2000", "real_price": 2000, "sort_order": 0, "category_id": 1, "selling_price": 2000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 500, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:08.654949+02
553	1	UPDATE	offers	20	{"id": 20, "name": "La Gold 2500", "is_active": true, "created_at": "2026-08-09T19:33:29.523Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-10T08:07:33.661Z", "category_id": 1, "selling_price": 2500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1250, "low_stock_threshold": 5}	{"name": "La Gold 2500", "real_price": 2500, "sort_order": 0, "category_id": 1, "selling_price": 2500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1250, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:12.190805+02
554	1	UPDATE	offers	23	{"id": 23, "name": "N'YOOZ 1000", "is_active": true, "created_at": "2026-08-09T19:34:48.637Z", "real_price": 1000, "sort_order": 0, "updated_at": "2026-08-09T19:34:48.637Z", "category_id": 2, "selling_price": 1000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 250, "low_stock_threshold": 5}	{"name": "N'YOOZ 1000", "real_price": 1000, "sort_order": 0, "category_id": 2, "selling_price": 1000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 250, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:20.557783+02
555	1	UPDATE	offers	24	{"id": 24, "name": "N'YOOZ 1500", "is_active": true, "created_at": "2026-08-09T19:35:04.610Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:35:04.610Z", "category_id": 2, "selling_price": 1500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 375, "low_stock_threshold": 5}	{"name": "N'YOOZ 1500", "real_price": 1500, "sort_order": 0, "category_id": 2, "selling_price": 1500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 375, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:24.157813+02
556	1	UPDATE	offers	12	{"id": 12, "name": "Dima 1200", "is_active": true, "created_at": "2026-08-09T19:31:05.178Z", "real_price": 1200, "sort_order": 0, "updated_at": "2026-08-09T19:31:05.178Z", "category_id": 3, "selling_price": 1200, "loyalty_points": 0, "commission_amount": 50, "commission_points": 300, "low_stock_threshold": 5}	{"name": "Dima 1200", "real_price": 1200, "sort_order": 0, "category_id": 3, "selling_price": 1200, "loyalty_points": 25, "commission_amount": 50, "commission_points": 300, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:31.243046+02
623	1	UPDATE	sim_balances	\N	\N	\N	Admin vault adjusted by -5000 SIMs	154.242.179.83	2026-08-25 21:47:13.810691+02
628	1	UPDATE	sim_balances	\N	\N	\N	Transferred 50 SIMs from store 2 to admin 1	154.242.179.83	2026-08-25 22:28:06.451363+02
629	1	UPDATE	sim_balances	\N	\N	\N	Transferred 50 SIMs from store 1 to admin 1	154.242.179.83	2026-08-25 22:28:21.483601+02
557	1	UPDATE	offers	14	{"id": 14, "name": "Dima 1500", "is_active": true, "created_at": "2026-08-09T19:31:36.791Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:31:36.791Z", "category_id": 3, "selling_price": 1500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 375, "low_stock_threshold": 5}	{"name": "Dima 1500", "real_price": 1500, "sort_order": 0, "category_id": 3, "selling_price": 1500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 375, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:35.926426+02
558	1	UPDATE	offers	16	{"id": 16, "name": "Dima 2500", "is_active": true, "created_at": "2026-08-09T19:32:19.892Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:32:19.892Z", "category_id": 3, "selling_price": 1700, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1250, "low_stock_threshold": 5}	{"name": "Dima 2500", "real_price": 2500, "sort_order": 0, "category_id": 3, "selling_price": 1700, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1250, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:41.467455+02
559	1	UPDATE	offers	15	{"id": 15, "name": "Dima 2000", "is_active": true, "created_at": "2026-08-09T19:32:01.092Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:32:01.092Z", "category_id": 3, "selling_price": 2000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 500, "low_stock_threshold": 5}	{"name": "Dima 2000", "real_price": 2000, "sort_order": 0, "category_id": 3, "selling_price": 2000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 500, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:46.982854+02
560	1	UPDATE	offers	7	{"id": 7, "name": "Ooredoo 500", "is_active": true, "created_at": "2026-08-09T19:28:22.840Z", "real_price": 500, "sort_order": 0, "updated_at": "2026-08-09T19:28:22.840Z", "category_id": 4, "selling_price": 500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 100, "low_stock_threshold": 5}	{"name": "Ooredoo 500", "real_price": 500, "sort_order": 0, "category_id": 4, "selling_price": 500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 100, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:51.358807+02
561	1	UPDATE	offers	8	{"id": 8, "name": "2500 : Ooredoo 500 * 6", "is_active": true, "created_at": "2026-08-09T19:28:54.819Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:28:54.819Z", "category_id": 4, "selling_price": 2500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1125, "low_stock_threshold": 5}	{"name": "2500 : Ooredoo 500 * 6", "real_price": 2500, "sort_order": 0, "category_id": 4, "selling_price": 2500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1125, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:43:55.275358+02
562	1	UPDATE	offers	9	{"id": 9, "name": "3500 : Ooredoo 500 * 9", "is_active": true, "created_at": "2026-08-09T19:29:27.390Z", "real_price": 3500, "sort_order": 0, "updated_at": "2026-08-09T19:29:27.390Z", "category_id": 4, "selling_price": 3500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1050, "low_stock_threshold": 5}	{"name": "3500 : Ooredoo 500 * 9", "real_price": 3500, "sort_order": 0, "category_id": 4, "selling_price": 3500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1050, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:44:00.326822+02
564	1	UPDATE	offers	11	{"id": 11, "name": "4990 : 200Go + Ooredoo 500 * 12", "is_active": true, "created_at": "2026-08-09T19:30:31.336Z", "real_price": 4990, "sort_order": 0, "updated_at": "2026-08-09T19:30:31.336Z", "category_id": 4, "selling_price": 4990, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1200, "low_stock_threshold": 5}	{"name": "4990 : 200Go + Ooredoo 500 * 12", "real_price": 4990, "sort_order": 0, "category_id": 4, "selling_price": 4990, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1200, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:44:10.945517+02
563	1	UPDATE	offers	10	{"id": 10, "name": "4500 : Ooredoo 500 * 12", "is_active": true, "created_at": "2026-08-09T19:29:59.463Z", "real_price": 4500, "sort_order": 0, "updated_at": "2026-08-09T19:29:59.463Z", "category_id": 4, "selling_price": 4500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1350, "low_stock_threshold": 5}	{"name": "4500 : Ooredoo 500 * 12", "real_price": 4500, "sort_order": 0, "category_id": 4, "selling_price": 4500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1350, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:44:05.830287+02
565	1	UPDATE	offers	25	{"id": 25, "name": "Ooredoo POP 1500", "is_active": true, "created_at": "2026-08-09T19:35:38.455Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:35:38.455Z", "category_id": 5, "selling_price": 1500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 150, "low_stock_threshold": 5}	{"name": "Ooredoo POP 1500", "real_price": 1500, "sort_order": 0, "category_id": 5, "selling_price": 1500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 150, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:45:07.879936+02
566	1	UPDATE	offers	6	{"id": 6, "name": "Ooredoo Internet 19500", "is_active": true, "created_at": "2026-08-09T19:27:53.748Z", "real_price": 19500, "sort_order": 0, "updated_at": "2026-08-09T19:27:53.748Z", "category_id": 6, "selling_price": 19500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 3900, "low_stock_threshold": 5}	{"name": "Ooredoo Internet 19500", "real_price": 19500, "sort_order": 0, "category_id": 6, "selling_price": 19500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 3900, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:45:13.694517+02
567	1	UPDATE	offers	5	{"id": 5, "name": "Ooredoo Internet 10000", "is_active": true, "created_at": "2026-08-09T19:27:35.838Z", "real_price": 10000, "sort_order": 0, "updated_at": "2026-08-09T19:27:35.838Z", "category_id": 6, "selling_price": 10000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 2000, "low_stock_threshold": 5}	{"name": "Ooredoo Internet 10000", "real_price": 10000, "sort_order": 0, "category_id": 6, "selling_price": 10000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 2000, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:45:46.23357+02
568	1	UPDATE	offers	4	{"id": 4, "name": "Ooredoo Internet 5500", "is_active": true, "created_at": "2026-08-09T19:27:15.405Z", "real_price": 5500, "sort_order": 0, "updated_at": "2026-08-09T19:27:15.405Z", "category_id": 6, "selling_price": 5500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1100, "low_stock_threshold": 5}	{"name": "Ooredoo Internet 5500", "real_price": 5500, "sort_order": 0, "category_id": 6, "selling_price": 5500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1100, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:45:50.327957+02
569	1	UPDATE	offers	3	{"id": 3, "name": "Ooredoo Internet 4500", "is_active": true, "created_at": "2026-08-09T19:26:51.995Z", "real_price": 4500, "sort_order": 0, "updated_at": "2026-08-09T19:26:51.995Z", "category_id": 6, "selling_price": 4500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 900, "low_stock_threshold": 5}	{"name": "Ooredoo Internet 4500", "real_price": 4500, "sort_order": 0, "category_id": 6, "selling_price": 4500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 900, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:45:53.864215+02
570	1	UPDATE	offers	2	{"id": 2, "name": "Ooredoo Internet 2500", "is_active": true, "created_at": "2026-08-09T19:26:30.345Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:26:30.345Z", "category_id": 6, "selling_price": 2500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 500, "low_stock_threshold": 5}	{"name": "Ooredoo Internet 2500", "real_price": 2500, "sort_order": 0, "category_id": 6, "selling_price": 2500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 500, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:45:57.417212+02
571	1	UPDATE	offers	1	{"id": 1, "name": "Ooredoo Internet 1500", "is_active": true, "created_at": "2026-08-09T19:25:58.312Z", "real_price": 1500, "sort_order": 0, "updated_at": "2026-08-09T19:25:58.312Z", "category_id": 6, "selling_price": 1500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 150, "low_stock_threshold": 5}	{"name": "Ooredoo Internet 1500", "real_price": 1500, "sort_order": 0, "category_id": 6, "selling_price": 1500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 150, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:02.482106+02
572	1	UPDATE	offers	29	{"id": 29, "name": "Ooredoo POP 4000", "is_active": true, "created_at": "2026-08-09T19:36:53.827Z", "real_price": 4000, "sort_order": 0, "updated_at": "2026-08-09T19:36:53.827Z", "category_id": 5, "selling_price": 4000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 1200, "low_stock_threshold": 5}	{"name": "Ooredoo POP 4000", "real_price": 4000, "sort_order": 0, "category_id": 5, "selling_price": 4000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 1200, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:06.458426+02
573	1	UPDATE	offers	28	{"id": 28, "name": "Ooredoo POP 2500", "is_active": true, "created_at": "2026-08-09T19:36:38.163Z", "real_price": 2500, "sort_order": 0, "updated_at": "2026-08-09T19:36:38.163Z", "category_id": 5, "selling_price": 2500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 750, "low_stock_threshold": 5}	{"name": "Ooredoo POP 2500", "real_price": 2500, "sort_order": 0, "category_id": 5, "selling_price": 2500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 750, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:10.312645+02
624	1	UPDATE	sim_balances	\N	\N	\N	Admin vault adjusted by -149 SIMs	154.242.179.83	2026-08-25 22:27:38.569968+02
625	1	UPDATE	sim_balances	\N	\N	\N	Admin vault adjusted by 1000 SIMs	154.242.179.83	2026-08-25 22:27:45.725366+02
626	1	UPDATE	sim_balances	\N	\N	\N	Transferred 500 SIMs from admin 1 to store 1	154.242.179.83	2026-08-25 22:27:52.071455+02
627	1	UPDATE	sim_balances	\N	\N	\N	Transferred 500 SIMs from admin 1 to store 2	154.242.179.83	2026-08-25 22:27:58.785696+02
574	1	UPDATE	offers	27	{"id": 27, "name": "Ooredoo POP 2000 0550", "is_active": true, "created_at": "2026-08-09T19:36:21.596Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:36:21.596Z", "category_id": 5, "selling_price": 2000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 0, "low_stock_threshold": 5}	{"name": "Ooredoo POP 2000 0550", "real_price": 2000, "sort_order": 0, "category_id": 5, "selling_price": 2000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 0, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:14.485871+02
575	1	UPDATE	offers	26	{"id": 26, "name": "Ooredoo POP 2000", "is_active": true, "created_at": "2026-08-09T19:35:55.762Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-09T19:35:55.762Z", "category_id": 5, "selling_price": 2000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 200, "low_stock_threshold": 5}	{"name": "Ooredoo POP 2000", "real_price": 2000, "sort_order": 0, "category_id": 5, "selling_price": 2000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 200, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:18.374917+02
576	1	UPDATE	offers	27	{"id": 27, "name": "Ooredoo POP 2000 0550", "is_active": true, "created_at": "2026-08-09T19:36:21.596Z", "real_price": 2000, "sort_order": 0, "updated_at": "2026-08-24T20:46:14.483Z", "category_id": 5, "selling_price": 2000, "loyalty_points": 25, "commission_amount": 50, "commission_points": 0, "low_stock_threshold": 5}	{"name": "Ooredoo POP 2000 0550", "real_price": 2000, "sort_order": 0, "category_id": 5, "selling_price": 2000, "loyalty_points": 0, "commission_amount": 50, "commission_points": 0, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:30.773355+02
577	1	UPDATE	offers	7	{"id": 7, "name": "Ooredoo 500", "is_active": true, "created_at": "2026-08-09T19:28:22.840Z", "real_price": 500, "sort_order": 0, "updated_at": "2026-08-24T20:43:51.357Z", "category_id": 4, "selling_price": 500, "loyalty_points": 25, "commission_amount": 50, "commission_points": 100, "low_stock_threshold": 5}	{"name": "Ooredoo 500", "real_price": 500, "sort_order": 0, "category_id": 4, "selling_price": 500, "loyalty_points": 0, "commission_amount": 50, "commission_points": 100, "low_stock_threshold": 5}	\N	154.242.182.234	2026-08-24 22:46:41.249602+02
578	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:48:44.481107+02
579	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:48:44.515684+02
580	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-24 22:48:44.546408+02
581	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-24 22:48:48.143149+02
582	2	SESSION_CLOSE	cashier_sessions	8	\N	\N	\N	154.242.182.234	2026-08-24 23:19:51.715472+02
583	2	LOGOUT	\N	\N	\N	\N	User "aymen_sobha" logged out	154.242.182.234	2026-08-24 23:19:53.275787+02
584	1	LOGOUT	\N	\N	\N	\N	User "admin" logged out	154.242.182.234	2026-08-24 23:25:37.856931+02
585	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-25 16:44:17.401131+02
586	2	SESSION_OPEN	cashier_sessions	9	\N	{"store_id": 1, "cashier_id": 2, "opening_cash": 0}	\N	154.242.179.83	2026-08-25 16:44:19.757912+02
587	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-25 16:47:28.28077+02
588	1	UPDATE	loyalty_settings	\N	\N	{"tier_vip": 2000, "tier_gold": 1000, "tier_vvip": 4000, "expiry_days": 90, "tier_bronze": 250, "tier_silver": 500, "point_to_dzd_value": 0.5, "storm_earn_percent": 1, "visit_bonus_points": 25, "min_points_to_redeem": 1000, "referral_bonus_points": 25, "visit_bonus_min_spend": 2000}	\N	154.242.179.83	2026-08-25 16:50:57.663003+02
589	1	UPDATE	loyalty_settings	\N	\N	{"tier_vip": 2000, "tier_gold": 1000, "tier_vvip": 4000, "expiry_days": 90, "tier_bronze": 250, "tier_silver": 500, "point_to_dzd_value": 1, "storm_earn_percent": 1, "visit_bonus_points": 25, "min_points_to_redeem": 600, "referral_bonus_points": 25, "visit_bonus_min_spend": 2000}	\N	154.242.179.83	2026-08-25 17:25:59.941082+02
590	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 18:47:38.125664+02
591	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 18:47:38.165255+02
592	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-25 18:47:43.104994+02
593	1	UPDATE	customers	51	\N	\N	Adjusted points by 50. Reason: Apologie for a mistake	154.242.179.83	2026-08-25 18:48:07.502872+02
594	1	UPDATE	customers	1	\N	\N	Adjusted points by -50. Reason: trying to stell a cable	154.242.179.83	2026-08-25 18:56:03.180901+02
595	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 19:10:03.632318+02
596	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 19:10:03.671819+02
597	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 19:10:03.689258+02
598	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 19:10:03.693933+02
599	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-25 19:10:07.648916+02
600	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.583612+02
602	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.588118+02
601	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.586546+02
604	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.608298+02
603	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.607604+02
605	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.617112+02
606	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.617821+02
607	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.618577+02
608	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.622412+02
609	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.705833+02
610	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:10:32.716783+02
611	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:21:56.17603+02
612	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:21:56.182889+02
613	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:21:56.20227+02
614	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 20:21:56.340024+02
615	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-25 21:27:12.627657+02
616	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-25 21:28:29.407656+02
617	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-25 21:34:39.827038+02
618	1	UPDATE	sim_balances	\N	\N	\N	Transferred 1500 SIMs from admin 1 to store 1	154.242.179.83	2026-08-25 21:36:07.673843+02
619	1	UPDATE	sim_balances	\N	\N	\N	Transferred 2000 SIMs from admin 1 to store 2	154.242.179.83	2026-08-25 21:36:21.887025+02
620	1	UPDATE	sim_balances	\N	\N	\N	Transferred 150 SIMs from store 1 to cashier 2	154.242.179.83	2026-08-25 21:36:35.482236+02
621	1	UPDATE	sim_balances	\N	\N	\N	Admin vault adjusted by -996500 SIMs	154.242.179.83	2026-08-25 21:44:50.068317+02
622	1	UPDATE	sim_balances	\N	\N	\N	Admin vault adjusted by 5000 SIMs	154.242.179.83	2026-08-25 21:47:09.509476+02
630	1	UPDATE	sim_balances	\N	\N	\N	Transferred 50 SIMs from admin 1 to store 1	154.242.179.83	2026-08-25 22:29:06.364514+02
631	1	UPDATE	sim_balances	\N	\N	\N	Transferred 50 SIMs from admin 1 to store 2	154.242.179.83	2026-08-25 22:29:10.967197+02
632	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:36.946462+02
633	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:36.993087+02
634	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.019611+02
635	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.101751+02
636	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.136117+02
637	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.140879+02
638	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.202158+02
639	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.227205+02
640	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.249541+02
641	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.289677+02
642	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:31:37.293473+02
643	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-25 22:31:42.152909+02
644	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-25 22:43:11.868338+02
645	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-25 22:43:15.966337+02
646	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.544583+02
647	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.553423+02
648	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.556944+02
649	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.558559+02
650	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.56526+02
651	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.583155+02
653	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.592006+02
652	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.591334+02
654	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.593363+02
655	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.617561+02
656	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:33.758458+02
657	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:34.580898+02
658	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:34.594471+02
659	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:34.598076+02
660	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 01:04:34.653141+02
661	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-26 16:28:23.934337+02
662	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-26 16:32:34.249829+02
663	1	UPDATE	loyalty_settings	\N	\N	{"tier_vip": 2000, "tier_gold": 1000, "tier_vvip": 4000, "expiry_days": 90, "tier_bronze": 250, "tier_silver": 500, "point_to_dzd_value": 1, "storm_earn_percent": 2, "visit_bonus_points": 25, "min_points_to_redeem": 600, "referral_bonus_points": 25, "visit_bonus_min_spend": 2000}	\N	154.242.183.157	2026-08-26 16:36:07.391853+02
664	1	UPDATE	loyalty_settings	\N	\N	{"tier_vip": 2000, "tier_gold": 1000, "tier_vvip": 4000, "expiry_days": 90, "tier_bronze": 250, "tier_silver": 500, "point_to_dzd_value": 1, "storm_earn_percent": 1, "visit_bonus_points": 25, "min_points_to_redeem": 600, "referral_bonus_points": 25, "visit_bonus_min_spend": 2000}	\N	154.242.183.157	2026-08-26 16:38:20.558472+02
665	1	REPORT_GENERATE	daily_reports	4	\N	{"date": "2026-08-24", "store_id": 1, "gross_profit": 685766.25, "total_revenue": 18115650}	\N	154.242.183.157	2026-08-26 17:01:49.043808+02
666	1	REPORT_GENERATE	daily_reports	5	\N	{"date": "2026-08-09", "store_id": 1, "gross_profit": 0}	\N	154.242.183.157	2026-08-26 17:20:27.004071+02
667	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 17:37:29.264813+02
668	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-26 17:37:34.788318+02
669	2	SESSION_CLOSE	cashier_sessions	9	\N	\N	\N	154.242.183.157	2026-08-26 18:18:50.230325+02
670	2	SESSION_OPEN	cashier_sessions	10	\N	{"store_id": 1, "cashier_id": 2, "opening_cash": 57500}	\N	154.242.183.157	2026-08-26 18:18:52.152789+02
671	1	REPORT_GENERATE	daily_reports	6	\N	{"date": "2026-08-25", "store_id": 1, "gross_profit": 87781.875}	\N	154.242.183.157	2026-08-26 18:19:18.128794+02
673	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 21:01:08.234701+02
672	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 21:01:08.233408+02
674	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 21:01:08.302444+02
675	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 21:01:08.311022+02
676	2	LOGIN	\N	\N	\N	\N	User "aymen_sobha" logged in	\N	2026-08-26 21:01:13.10415+02
677	1	LOGOUT	\N	\N	\N	\N	User "admin" logged out	154.242.183.157	2026-08-26 21:05:04.660284+02
678	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-26 21:05:06.716544+02
679	1	UPDATE	loyalty_settings	\N	\N	{"tier_vip": 2000, "tier_gold": 1000, "tier_vvip": 4000, "expiry_days": 90, "tier_bronze": 250, "tier_silver": 500, "point_to_dzd_value": 1, "storm_earn_percent": 1, "visit_bonus_points": 25, "min_points_to_redeem": 600, "referral_bonus_points": 25, "visit_bonus_min_spend": 2000}	\N	154.242.183.157	2026-08-26 21:07:25.101836+02
680	1	UPDATE	customers	51	\N	\N	Adjusted points by 50. Reason: 00000	154.242.183.157	2026-08-26 21:12:47.236388+02
681	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.176432+02
682	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.210086+02
683	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.223587+02
684	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.225832+02
685	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.227903+02
686	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.234636+02
687	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.235285+02
688	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.23599+02
689	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-26 22:48:36.236565+02
690	2	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 02:01:50.665507+02
691	1	LOGIN	\N	\N	\N	\N	User "admin" logged in	\N	2026-08-27 16:36:22.217584+02
693	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.172893+02
694	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.174418+02
695	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.177212+02
696	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.179262+02
692	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.171232+02
697	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.196756+02
698	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.197547+02
699	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.203224+02
700	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.224668+02
701	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.231842+02
702	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.233791+02
703	1	LOGIN	\N	\N	\N	\N	Refresh token reuse detected — all sessions revoked	\N	2026-08-27 18:16:44.235772+02
\.


--
-- TOC entry 5450 (class 0 OID 25961)
-- Dependencies: 258
-- Data for Name: cashier_advances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cashier_advances (id, cashier_id, amount, direction, note, is_voided, void_reason, voided_at, voided_by, created_by, created_at, session_id) FROM stdin;
\.


--
-- TOC entry 5428 (class 0 OID 16965)
-- Dependencies: 234
-- Data for Name: cashier_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cashier_sessions (id, cashier_id, store_id, session_date, status, opening_cash, closed_at, created_at, closing_cash, cash_discrepancy) FROM stdin;
1	2	1	2026-08-09	closed	0.00	2026-08-10 09:23:50.529703+02	2026-08-09 21:40:38.551204+02	\N	\N
3	3	1	2026-08-10	closed	16215.00	2026-08-10 19:25:56.862236+02	2026-08-10 11:13:53.563675+02	\N	\N
2	2	1	2026-08-10	closed	0.00	2026-08-10 23:03:11.178398+02	2026-08-10 09:23:51.786347+02	49980.00	0.00
6	3	1	2026-08-11	closed	10594.00	2026-08-11 19:25:41.800249+02	2026-08-11 11:23:52.389997+02	4529.00	0.00
5	5	2	2026-08-11	closed	0.00	2026-08-11 20:05:58.636413+02	2026-08-11 09:21:30.628218+02	34520.00	0.00
4	2	1	2026-08-11	closed	0.00	2026-08-11 22:50:49.177383+02	2026-08-11 09:15:42.972035+02	29874.00	0.00
7	4	2	2026-08-11	closed	29720.00	2026-08-11 22:52:07.183462+02	2026-08-11 16:02:57.032325+02	41795.00	0.00
8	2	1	2026-08-24	closed	0.00	2026-08-24 23:19:51.708751+02	2026-08-24 20:02:46.815863+02	409519.00	0.00
9	2	1	2026-08-25	closed	0.00	2026-08-26 18:18:50.216251+02	2026-08-25 16:44:19.753336+02	2461275.00	2403775.00
10	2	1	2026-08-26	open	57500.00	\N	2026-08-26 18:18:52.147225+02	\N	\N
\.


--
-- TOC entry 5448 (class 0 OID 17443)
-- Dependencies: 256
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (id, phone_number, first_name, last_name, address, profession, notes, created_by, created_at, updated_at, available_points, lifetime_points, referred_by, referral_rewarded, last_purchase_at) FROM stdin;
54	0569843216	Imad Eddine	Benbali	Bali	Indonesia	\N	2	2026-08-26 16:32:11.671156+02	2026-08-26 16:32:12.037643+02	100.00	100.00	\N	f	2026-08-26 16:32:12.037643+02
51	0559516365	Aymen	Hamidi	Abbas ElHadj Cite 08 Mai 1945	Pizzario	\N	2	2026-08-25 17:01:32.756527+02	2026-08-26 21:12:47.156657+02	107.55	1617.55	\N	f	2026-08-25 17:02:47.093121+02
22	0550410322	Client	CC	Sobha	trav	\N	3	2026-08-10 14:55:21.717213+02	2026-08-24 22:56:05.853022+02	17.00	17.00	\N	f	\N
11	0541761222	Fatiha	mezdek	bocca ouled ziad	house wife	\N	3	2026-08-10 11:34:00.910379+02	2026-08-24 22:56:05.853022+02	5.00	5.00	\N	f	\N
44	0550433799	Abdel hamid	Aissaoui	cité ouled salem	ret	\N	3	2026-08-11 14:03:01.922053+02	2026-08-24 22:56:05.853022+02	0.00	0.00	\N	f	\N
9	0542502749	NASSREDDINE	BACHIRI	Bocca El Amalssa	Traivieur Journallier	\N	2	2026-08-10 11:08:04.63684+02	2026-08-24 22:56:05.853022+02	10.00	10.00	\N	f	\N
19	050000	Mohammed	Meddah	bocca amalssa	Travaillier Journallier	\N	3	2026-08-10 14:08:57.93405+02	2026-08-24 22:56:05.853022+02	2.50	2.50	\N	f	\N
21	0554137333	Fethi	Khelifa zoubir	city ben zergha chaibe dour	student	\N	3	2026-08-10 14:41:19.385208+02	2026-08-24 22:56:05.853022+02	15.00	15.00	\N	f	\N
3	0550907433	ZID ELKHIR	ABDELKHALAQ	Cité Martyrs Abouche Mohamed	Travaier Journalier	\N	2	2026-08-10 09:31:47.050056+02	2026-08-24 22:56:05.853022+02	20.00	20.00	\N	f	\N
17	0540218996	Moussa	Letrach	bocca ouled fetti	Traivieur Journallier	\N	3	2026-08-10 12:38:46.425504+02	2026-08-24 22:56:05.853022+02	20.00	20.00	\N	f	\N
5	0564004546	HAMID	MOUSSAOUI	Bocca Ouled Ziad	Immigrer	\N	2	2026-08-10 10:07:13.587579+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
4	0564045873	HOURIA	AMRI	Cité Abed Azzi	Etudiant	\N	2	2026-08-10 09:36:23.802762+02	2026-08-24 22:56:05.853022+02	0.00	0.00	\N	f	\N
10	0564173649	KARIM	AFFOU	Bocca El Aouana	Travaillier Journallier	\N	3	2026-08-10 11:29:20.016799+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
6	0564011034	LAIKA	NOURINE	Cité Martyrs Ben Zarga Chaib Eddour	Etudiant	\N	2	2026-08-10 10:18:24.582538+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
13	0564164152	Mohammed	M guebbel	bocca ouled salem	Travaillier Journallier	\N	3	2026-08-10 12:05:12.049723+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
2	0554198047	BENSID AHMED	MEROUAN	Bocca Ouled Salem	Retraité	\N	2	2026-08-10 09:25:49.027231+02	2026-08-24 22:56:05.853022+02	5.00	5.00	\N	f	\N
16	0564184724	Fatiha	Hadj elezaar	Sobha-hey chamali	house wife	\N	3	2026-08-10 12:24:59.433147+02	2026-08-24 22:56:05.853022+02	0.00	0.00	\N	f	\N
46	0550543669	Abdelkadir	Belhadj benyahia	cité sobha center	trav	\N	3	2026-08-11 17:20:32.194438+02	2026-08-24 22:56:05.853022+02	0.00	0.00	\N	f	\N
7	0550684621	AbdElKader	Hamadi	Bocca Ouled Hamadi	Chauffeur	\N	2	2026-08-10 10:33:57.015671+02	2026-08-24 22:56:05.853022+02	11.75	11.75	\N	f	\N
12	0551334899	Fares	Sahil	hey zaouya	student	\N	3	2026-08-10 11:45:09.741494+02	2026-08-24 22:56:05.853022+02	1.90	1.90	\N	f	\N
18	0558411398	Rachid	Benbrik	sobha	student	\N	3	2026-08-10 12:48:15.337033+02	2026-08-24 22:56:05.853022+02	2.00	2.00	\N	f	\N
52	0556365912	Imad	Eddine	Ain Meriane	Consier de vente	\N	2	2026-08-26 16:29:25.584151+02	2026-08-26 16:29:26.199716+02	25.00	25.00	\N	f	2026-08-26 16:29:26.199716+02
15	0557772076	Salem	Hamid	sobha center	Travaillier Journallier	\N	3	2026-08-10 12:20:08.080961+02	2026-08-24 22:56:05.853022+02	5.00	5.00	\N	f	\N
28	050000000	Client	Ooredoo	Sobha	trav	\N	3	2026-08-10 18:25:53.248296+02	2026-08-24 22:56:05.853022+02	14.00	14.00	\N	f	\N
31	0559379917	00000	0000	00	house wife	\N	3	2026-08-11 11:27:31.272019+02	2026-08-24 22:56:05.853022+02	10.75	10.75	\N	f	\N
32	0558704129	000	0	0	0	\N	3	2026-08-11 11:39:42.676157+02	2026-08-24 22:56:05.853022+02	10.00	10.00	\N	f	\N
24	0542875350	Bou abedlla	benhenni	sobha center	tra	\N	3	2026-08-10 17:24:46.631375+02	2026-08-24 22:56:05.853022+02	10.75	10.75	\N	f	\N
25	05000000	client	Ooredoo	sobha center	travieur	\N	3	2026-08-10 17:30:39.74033+02	2026-08-24 22:56:05.853022+02	15.00	15.00	\N	f	\N
20	0550942244	Mohammed	Hamadi	bocca ouled hamadi	Travaillier Journallier	\N	3	2026-08-10 14:36:22.130389+02	2026-08-24 22:56:05.853022+02	15.00	15.00	\N	f	\N
33	0552284283	chaimaa	boukhobza	0	0	\N	3	2026-08-11 11:41:15.77894+02	2026-08-24 22:56:05.853022+02	10.00	10.00	\N	f	\N
27	0564682822	Abdelkadir	Laameche	sobha center	ecommerce	\N	3	2026-08-10 17:45:37.676653+02	2026-08-24 22:56:05.853022+02	2.00	2.00	\N	f	\N
42	0558774111	0	0	0	0	\N	3	2026-08-11 13:49:44.331345+02	2026-08-24 22:56:05.853022+02	5.00	5.00	\N	f	\N
40	0555775287	Rayene	daheman	sobha center	student	\N	3	2026-08-11 13:20:33.661323+02	2026-08-24 22:56:05.853022+02	2.00	2.00	\N	f	\N
43	0551354082	0	0	0	0	\N	3	2026-08-11 13:54:54.485975+02	2026-08-24 22:56:05.853022+02	2.00	2.00	\N	f	\N
48	0564042794	Fatima	Ali abbes	cité 40masken	house wife	\N	3	2026-08-11 18:38:05.193669+02	2026-08-24 22:56:05.853022+02	0.00	0.00	\N	f	\N
26	0564170247	Fatiha	Benbrik	hey chamali	house wife	\N	3	2026-08-10 17:40:56.563369+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
30	0564175556	Adem	Menaouta	Bocca El Hechalif	Nothing	\N	2	2026-08-10 19:55:52.966275+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
37	0564109130	Benyahia	Chaib eddour	cite 08 mai 1945	ensenient	\N	3	2026-08-11 12:37:19.137498+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
29	0564173278	Houria	Cherbal	Cité Nord	House Wife	\N	3	2026-08-10 19:16:40.621443+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
34	0541297855	00	00	0	0	\N	3	2026-08-11 12:03:19.799701+02	2026-08-24 22:56:05.853022+02	2.00	2.00	\N	f	\N
35	0555054785	0	0	0	0	\N	3	2026-08-11 12:05:04.569456+02	2026-08-24 22:56:05.853022+02	5.00	5.00	\N	f	\N
45	0000050	0	0	0	0	\N	3	2026-08-11 14:07:19.670805+02	2026-08-24 22:56:05.853022+02	10.00	10.00	\N	f	\N
39	0564109214	Samir	Benaama	Cité Abed azzi	travaieur	\N	3	2026-08-11 13:16:32.331534+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
36	0559184224	amin	baydor	Cité ouled jilali	student	\N	3	2026-08-11 12:32:36.907513+02	2026-08-24 22:56:05.853022+02	20.00	20.00	\N	f	\N
14	0564176668	Hocine	Hadj-Mostefa	hey ouled mostefa	Travaillier Journallier	\N	3	2026-08-10 12:16:55.118958+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
41	0551889569	0	0	0	0	\N	3	2026-08-11 13:48:56.685234+02	2026-08-24 22:56:05.853022+02	2.00	2.00	\N	f	\N
38	0564112113	Roufaida	Mokhfi	cite elhechalif	student	\N	3	2026-08-11 12:58:25.095768+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
49	0564047237	0	0	00	tra	\N	3	2026-08-11 18:39:37.071573+02	2026-08-24 22:56:05.853022+02	5.00	5.00	\N	f	\N
47	0552962015	0	0	0	0	\N	3	2026-08-11 17:25:41.627729+02	2026-08-24 22:56:05.853022+02	2.30	2.30	\N	f	\N
23	0564195166	Mostafa	Yahiaoui	bocca ouled jilali	Travaillier Journallier	\N	3	2026-08-10 15:58:35.491287+02	2026-08-24 22:56:05.853022+02	25.00	25.00	\N	f	\N
8	0561444340	Mohamed	Kharoubi	Cité 08 Mai 1945	Commerçant	\N	2	2026-08-10 10:41:34.20855+02	2026-08-24 22:56:05.853022+02	20.00	20.00	\N	f	\N
53	0562359812	Imade Eddin	Benbali	Ain Meraine	Nothing	\N	2	2026-08-26 16:30:41.880412+02	2026-08-26 16:30:42.232669+02	15.00	15.00	\N	f	2026-08-26 16:30:42.232669+02
50	0559516395	Aymen	Hamidi	Abbas ElHadj Cite 08 Mai 1945	Student	\N	2	2026-08-24 21:45:25.866571+02	2026-08-26 21:01:37.151991+02	180.50	861.50	\N	f	2026-08-26 21:01:37.151991+02
1	0559516359	Junk	Customer	Cité Martyrs Abouche Mohamed	Nothing	\N	1	2026-08-09 21:42:04.382833+02	2026-08-26 21:02:58.848808+02	267.44	1767.44	\N	f	2026-08-26 21:02:58.848808+02
\.


--
-- TOC entry 5442 (class 0 OID 17205)
-- Dependencies: 248
-- Data for Name: daily_reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.daily_reports (id, report_date, store_id, created_by, created_at, total_sim_units, total_real_price, total_selling_price, total_points, total_storm, total_accessories, total_debts, total_commissions, gross_profit, snapshot, loyalty_points_redeemed, loyalty_driven_revenue) FROM stdin;
1	2026-08-10	1	1	2026-08-10 23:12:55.708479+02	16	32500.00	24500.00	14925	25480.00	0.00	0.00	800.00	7574.50	{"register": {"updated_at": "2026-08-10T19:55:28.524Z", "cash_amount": 49980}, "sessions": [{"debts": [], "store_id": 1, "sim_sales": [{"id": 5, "sold_at": "2026-08-10T09:29:28.839Z", "offer_id": 20, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 6, "sold_at": "2026-08-10T10:05:21.017Z", "offer_id": 20, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 7, "sold_at": "2026-08-10T10:17:02.166Z", "offer_id": 20, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 8, "sold_at": "2026-08-10T10:25:07.561Z", "offer_id": 7, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 9, "sold_at": "2026-08-10T13:58:42.496Z", "offer_id": 20, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 10, "sold_at": "2026-08-10T15:41:03.046Z", "offer_id": 20, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 11, "sold_at": "2026-08-10T17:16:45.242Z", "offer_id": 20, "is_voided": false, "session_id": 3, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}], "cashier_id": 3, "debt_total": 0, "session_id": 3, "store_name": "AAO Sobha", "storm_total": 11415, "cashier_name": "Fatiha", "opening_cash": 16215, "session_date": "2026-08-09T22:00:00.000Z", "storm_entries": [{"id": 10, "note": "USSD (*585#) Bundle | Phone: (0541761222)", "amount": 500, "is_voided": false, "entered_at": "2026-08-10T09:34:01.169Z", "session_id": 3, "void_reason": null}, {"id": 11, "note": "USSD (*580#) Op: 26472969 | Phone: (0551334899)", "amount": 190, "is_voided": false, "entered_at": "2026-08-10T09:45:10.016Z", "session_id": 3, "void_reason": null}, {"id": 12, "note": "USSD (*585#) Bundle | Phone: (0557772076)", "amount": 500, "is_voided": false, "entered_at": "2026-08-10T10:20:08.519Z", "session_id": 3, "void_reason": null}, {"id": 13, "note": "USSD (*580#) Op: 26641278 | Phone: (0540218996)", "amount": 2000, "is_voided": false, "entered_at": "2026-08-10T10:38:46.728Z", "session_id": 3, "void_reason": null}, {"id": 14, "note": "USSD (*580#) Op: 40154735 | Phone: (0558411398)", "amount": 200, "is_voided": false, "entered_at": "2026-08-10T10:48:15.788Z", "session_id": 3, "void_reason": null}, {"id": 15, "note": "Flexy", "amount": 250, "is_voided": false, "entered_at": "2026-08-10T12:08:58.329Z", "session_id": 3, "void_reason": null}, {"id": 16, "note": "USSD (*585#) Bundle | Phone: (0550942244)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-10T12:36:22.502Z", "session_id": 3, "void_reason": null}, {"id": 17, "note": "USSD (*585#) Bundle | Phone: (0554137333)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-10T12:41:19.773Z", "session_id": 3, "void_reason": null}, {"id": 18, "note": "USSD (*585#) Bundle | Phone: (0550410322)", "amount": 200, "is_voided": false, "entered_at": "2026-08-10T12:55:22.152Z", "session_id": 3, "void_reason": null}, {"id": 19, "note": "USSD (*585#) Bundle | Phone: (0542875350)", "amount": 1075, "is_voided": false, "entered_at": "2026-08-10T15:24:47.397Z", "session_id": 3, "void_reason": null}, {"id": 20, "note": "Flexy", "amount": 1500, "is_voided": false, "entered_at": "2026-08-10T15:30:40.057Z", "session_id": 3, "void_reason": null}, {"id": 21, "note": "USSD (*580#) Op: 41025044 | Phone: (0564682822)", "amount": 200, "is_voided": false, "entered_at": "2026-08-10T15:45:37.992Z", "session_id": 3, "void_reason": null}, {"id": 22, "note": "Flexy", "amount": 1400, "is_voided": false, "entered_at": "2026-08-10T16:25:53.680Z", "session_id": 3, "void_reason": null}, {"id": 23, "note": "Flexy", "amount": 400, "is_voided": false, "entered_at": "2026-08-10T17:25:39.265Z", "session_id": 3, "void_reason": null}], "sim_units_sold": 7, "accessory_sales": [], "sim_total_points": 7600, "sim_total_profit": 2800, "accessories_total": 0, "sim_total_commission": 350, "sim_total_real_price": 15500, "total_cashier_benefit": 350, "expected_register_cash": 49980, "sim_total_selling_price": 10700, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}, {"debts": [], "store_id": 1, "sim_sales": [{"id": 1, "sold_at": "2026-08-10T07:43:24.596Z", "offer_id": 7, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 2, "sold_at": "2026-08-10T08:08:01.694Z", "offer_id": 20, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 2500}, {"id": 3, "sold_at": "2026-08-10T08:18:25.998Z", "offer_id": 19, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 500, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2000", "real_price_snapshot": 2000, "selling_price_snapshot": 2000}, {"id": 4, "sold_at": "2026-08-10T08:37:04.917Z", "offer_id": 18, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 375, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1500", "real_price_snapshot": 1500, "selling_price_snapshot": 1500}, {"id": 12, "sold_at": "2026-08-10T17:55:59.019Z", "offer_id": 20, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 13, "sold_at": "2026-08-10T18:14:43.445Z", "offer_id": 16, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 14, "sold_at": "2026-08-10T18:18:34.157Z", "offer_id": 7, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 15, "sold_at": "2026-08-10T19:16:08.815Z", "offer_id": 20, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 16, "sold_at": "2026-08-10T19:55:28.524Z", "offer_id": 20, "is_voided": false, "session_id": 2, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}], "cashier_id": 2, "debt_total": 0, "session_id": 2, "store_name": "AAO Sobha", "storm_total": 14065, "cashier_name": "Aymen", "opening_cash": 0, "session_date": "2026-08-09T22:00:00.000Z", "storm_entries": [{"id": 1, "note": "USSD (*585#) Bundle | Phone: (0554198047)", "amount": 500, "is_voided": false, "entered_at": "2026-08-10T07:25:49.812Z", "session_id": 2, "void_reason": null}, {"id": 2, "note": "USSD (*585#) Bundle | Phone: (0558802704)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-10T07:29:06.651Z", "session_id": 2, "void_reason": null}, {"id": 3, "note": "USSD (*580#) Op: 39644414 | Phone: (0550907433)", "amount": 2000, "is_voided": false, "entered_at": "2026-08-10T07:31:47.309Z", "session_id": 2, "void_reason": null}, {"id": 4, "note": "0561298790", "amount": 300, "is_voided": false, "entered_at": "2026-08-10T08:06:12.003Z", "session_id": 2, "void_reason": null}, {"id": 5, "note": "USSD (*585#) Bundle | Phone: (0542511252)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-10T08:12:34.562Z", "session_id": 2, "void_reason": null}, {"id": 6, "note": "USSD (*585#) Bundle | Phone: (0550684621)", "amount": 1175, "is_voided": false, "entered_at": "2026-08-10T08:33:57.311Z", "session_id": 2, "void_reason": null}, {"id": 7, "note": "USSD (*585#) Bundle | Phone: (0561444340)", "amount": 2000, "is_voided": false, "entered_at": "2026-08-10T08:41:34.596Z", "session_id": 2, "void_reason": null}, {"id": 8, "note": "USSD (*580#) Op: 39813261 | Phone: (0541430600)", "amount": 240, "is_voided": false, "entered_at": "2026-08-10T08:52:02.670Z", "session_id": 2, "void_reason": null}, {"id": 9, "note": "USSD (*585#) Bundle | Phone: (0542502749)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-10T09:08:04.937Z", "session_id": 2, "void_reason": null}, {"id": 24, "note": "USSD (*585#) Bundle | Phone: (0553476892)", "amount": 500, "is_voided": false, "entered_at": "2026-08-10T17:49:44.679Z", "session_id": 2, "void_reason": null}, {"id": 25, "note": "USSD (*580#) Op: 41433581 | Phone: (0551977624)", "amount": 150, "is_voided": false, "entered_at": "2026-08-10T17:50:55.223Z", "session_id": 2, "void_reason": null}, {"id": 26, "note": "USSD (*580#) Op: 41462742 | Phone: (0562651981)", "amount": 200, "is_voided": false, "entered_at": "2026-08-10T17:59:02.426Z", "session_id": 2, "void_reason": null}, {"id": 27, "note": "USSD (*585#) Bundle | Phone: (0556409215)", "amount": 2000, "is_voided": false, "entered_at": "2026-08-10T18:08:50.380Z", "session_id": 2, "void_reason": null}, {"id": 28, "note": "USSD (*580#) Op: 15380569 | Phone: (0541621932)", "amount": 500, "is_voided": false, "entered_at": "2026-08-10T18:30:10.386Z", "session_id": 2, "void_reason": null}, {"id": 29, "note": "USSD (*585#) Bundle | Phone: (0563500123)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-10T18:42:02.254Z", "session_id": 2, "void_reason": null}], "sim_units_sold": 9, "accessory_sales": [], "sim_total_points": 7325, "sim_total_profit": 4125, "accessories_total": 0, "sim_total_commission": 450, "sim_total_real_price": 17000, "total_cashier_benefit": 450, "expected_register_cash": 49980, "sim_total_selling_price": 13800, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}], "global_pool": {"updated_at": "2026-08-10T20:59:10.607Z", "available_bonus": 144166.55, "available_points": 0, "available_balance": 69137.54}}	0.00	0.00
2	2026-08-11	1	1	2026-08-11 22:52:20.113363+02	18	36500.00	26500.00	14950	47964.00	0.00	0.00	900.00	6161.60	{"register": {"updated_at": "2026-08-11T20:48:02.059Z", "cash_amount": 29874}, "sessions": [{"debts": [], "store_id": 1, "sim_sales": [{"id": 26, "sold_at": "2026-08-11T09:34:58.959Z", "offer_id": 18, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 375, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1500", "real_price_snapshot": 1500, "selling_price_snapshot": 1500}, {"id": 31, "sold_at": "2026-08-11T10:37:40.563Z", "offer_id": 20, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1300}, {"id": 37, "sold_at": "2026-08-11T10:59:06.305Z", "offer_id": 20, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1500}, {"id": 38, "sold_at": "2026-08-11T11:16:41.643Z", "offer_id": 20, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1300}, {"id": 39, "sold_at": "2026-08-11T12:03:07.325Z", "offer_id": 27, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 0, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo POP 2000 0550", "real_price_snapshot": 2000, "selling_price_snapshot": 2000}, {"id": 42, "sold_at": "2026-08-11T15:20:54.443Z", "offer_id": 27, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 0, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo POP 2000 0550", "real_price_snapshot": 2000, "selling_price_snapshot": 2000}, {"id": 43, "sold_at": "2026-08-11T16:38:08.186Z", "offer_id": 7, "is_voided": false, "session_id": 6, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}], "cashier_id": 3, "debt_total": 0, "session_id": 6, "store_name": "AAO Sobha", "storm_total": 28425, "cashier_name": "Fatiha", "opening_cash": 10594, "session_date": "2026-08-10T22:00:00.000Z", "storm_entries": [{"id": 42, "note": "USSD (*585#) Bundle | Phone: (0559379917)", "amount": 1075, "is_voided": false, "entered_at": "2026-08-11T09:27:32.498Z", "session_id": 6, "void_reason": null}, {"id": 43, "note": "USSD (*585#) Bundle | Phone: (0557689981)", "amount": 1575, "is_voided": false, "entered_at": "2026-08-11T09:36:41.893Z", "session_id": 6, "void_reason": null}, {"id": 44, "note": "USSD (*580#) Op: 17111250 | Phone: (0552129917)", "amount": 2000, "is_voided": false, "entered_at": "2026-08-11T09:37:43.550Z", "session_id": 6, "void_reason": null}, {"id": 45, "note": "USSD (*585#) Bundle | Phone: (0558704129)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T09:39:42.977Z", "session_id": 6, "void_reason": null}, {"id": 46, "note": "USSD (*580#) Op: 17119954 | Phone: (0552284283)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T09:41:16.072Z", "session_id": 6, "void_reason": null}, {"id": 47, "note": "Manual POS Entry | Phone: (${})", "amount": 100, "is_voided": false, "entered_at": "2026-08-11T09:54:16.218Z", "session_id": 6, "void_reason": null}, {"id": 48, "note": "Manual POS Entry | Phone: (${})", "amount": 100, "is_voided": false, "entered_at": "2026-08-11T09:54:25.697Z", "session_id": 6, "void_reason": null}, {"id": 49, "note": "Manual POS Entry | Phone: (${})", "amount": 45, "is_voided": false, "entered_at": "2026-08-11T09:56:34.091Z", "session_id": 6, "void_reason": null}, {"id": 50, "note": "USSD (*585#) Bundle | Phone: (0541297855)", "amount": 200, "is_voided": false, "entered_at": "2026-08-11T10:03:20.133Z", "session_id": 6, "void_reason": null}, {"id": 51, "note": "USSD (*580#) Op: 260429463050 | Phone: (0555054785)", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T10:05:04.866Z", "session_id": 6, "void_reason": null}, {"id": 53, "note": "USSD (*585#) Bundle | Phone: (0559184224)", "amount": 2000, "is_voided": false, "entered_at": "2026-08-11T10:32:37.228Z", "session_id": 6, "void_reason": null}, {"id": 56, "note": "USSD (*580#) Op: 30159488 | Phone: (0555775287)", "amount": 200, "is_voided": false, "entered_at": "2026-08-11T11:20:33.992Z", "session_id": 6, "void_reason": null}, {"id": 58, "note": "USSD (*580#) Op: 30250784 | Phone: (0551889569)", "amount": 200, "is_voided": false, "entered_at": "2026-08-11T11:48:56.986Z", "session_id": 6, "void_reason": null}, {"id": 59, "note": "USSD (*580#) Op: 17522420 | Phone: (0558774111)", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T11:49:44.622Z", "session_id": 6, "void_reason": null}, {"id": 60, "note": "USSD (*580#) Op: 260429506914 | Phone: (0551354082)", "amount": 200, "is_voided": false, "entered_at": "2026-08-11T11:54:54.798Z", "session_id": 6, "void_reason": null}, {"id": 61, "note": "Flexy", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T12:07:19.980Z", "session_id": 6, "void_reason": null}, {"id": 62, "note": "USSD (*580#) Op: 240429214520 | Phone: (0552962015)", "amount": 230, "is_voided": false, "entered_at": "2026-08-11T15:25:41.995Z", "session_id": 6, "void_reason": null}, {"id": 63, "note": "USSD (*585#) Bundle | Phone: (0564047237)", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T16:39:37.387Z", "session_id": 6, "void_reason": null}, {"id": 64, "note": "Ooredoo POP 2000", "amount": 160000, "is_voided": true, "entered_at": "2026-08-11T17:18:13.383Z", "session_id": 6, "void_reason": "Wrong Amount"}, {"id": 65, "note": "Ooredoo POP 2000 1 Year Avance", "amount": 16000, "is_voided": false, "entered_at": "2026-08-11T17:19:00.751Z", "session_id": 6, "void_reason": null}], "sim_units_sold": 7, "accessory_sales": [], "sim_total_points": 4225, "sim_total_profit": 825, "accessories_total": 0, "sim_total_commission": 350, "sim_total_real_price": 13500, "total_cashier_benefit": 350, "expected_register_cash": 29874, "sim_total_selling_price": 10100, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}, {"debts": [], "store_id": 1, "sim_sales": [{"id": 21, "sold_at": "2026-08-11T08:39:13.787Z", "offer_id": 16, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 22, "sold_at": "2026-08-11T08:59:44.199Z", "offer_id": 16, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 45, "sold_at": "2026-08-11T17:27:52.879Z", "offer_id": 20, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 46, "sold_at": "2026-08-11T17:28:03.192Z", "offer_id": 18, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 375, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1500", "real_price_snapshot": 1500, "selling_price_snapshot": 1500}, {"id": 48, "sold_at": "2026-08-11T18:10:22.604Z", "offer_id": 16, "is_voided": true, "session_id": 4, "void_reason": "Wrong Price", "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 49, "sold_at": "2026-08-11T18:11:25.079Z", "offer_id": 16, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1500}, {"id": 52, "sold_at": "2026-08-11T18:43:45.485Z", "offer_id": 20, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 53, "sold_at": "2026-08-11T18:54:02.204Z", "offer_id": 17, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000}, {"id": 54, "sold_at": "2026-08-11T19:22:32.837Z", "offer_id": 20, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 55, "sold_at": "2026-08-11T19:22:43.353Z", "offer_id": 20, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 56, "sold_at": "2026-08-11T19:23:51.339Z", "offer_id": 7, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 57, "sold_at": "2026-08-11T20:30:35.535Z", "offer_id": 20, "is_voided": true, "session_id": 4, "void_reason": "000000", "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}, {"id": 60, "sold_at": "2026-08-11T20:47:30.277Z", "offer_id": 20, "is_voided": true, "session_id": 4, "void_reason": "Customer change his mind", "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1695}, {"id": 61, "sold_at": "2026-08-11T20:48:02.059Z", "offer_id": 20, "is_voided": false, "session_id": 4, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1700}], "cashier_id": 2, "debt_total": 0, "session_id": 4, "store_name": "AAO Sobha", "storm_total": 19539, "cashier_name": "Aymen", "opening_cash": 0, "session_date": "2026-08-10T22:00:00.000Z", "storm_entries": [{"id": 31, "note": "USSD (*585#) Bundle | Phone: (0551008928)", "amount": 2598, "is_voided": false, "entered_at": "2026-08-11T07:48:09.325Z", "session_id": 4, "void_reason": null}, {"id": 32, "note": "USSD (*585#) Bundle | Phone: (0557124539)", "amount": 1098, "is_voided": false, "entered_at": "2026-08-11T07:53:13.655Z", "session_id": 4, "void_reason": null}, {"id": 33, "note": "USSD (*585#) Bundle | Phone: (0549541374)", "amount": 1598, "is_voided": false, "entered_at": "2026-08-11T08:05:56.458Z", "session_id": 4, "void_reason": null}, {"id": 34, "note": "USSD (*585#) Bundle | Phone: (0549560878)", "amount": 200, "is_voided": false, "entered_at": "2026-08-11T08:10:04.044Z", "session_id": 4, "void_reason": null}, {"id": 37, "note": "USSD (*580#) Op: 29710624 | Phone: (0556221776)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T08:51:56.413Z", "session_id": 4, "void_reason": null}, {"id": 38, "note": "USSD (*580#) Op: 240429079102 | Phone: (0561880560)", "amount": 100, "is_voided": false, "entered_at": "2026-08-11T08:58:56.159Z", "session_id": 4, "void_reason": null}, {"id": 39, "note": "USSD (*580#) Op: 29748138 | Phone: (0540878664)", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T09:06:19.530Z", "session_id": 4, "void_reason": null}, {"id": 41, "note": "flexy", "amount": 100, "is_voided": false, "entered_at": "2026-08-11T09:12:57.472Z", "session_id": 4, "void_reason": null}, {"id": 66, "note": "USSD (*580#) Op: 240429266011 | Phone: (0561351086)", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T17:30:42.705Z", "session_id": 4, "void_reason": null}, {"id": 67, "note": "Manual POS Entry | Phone: (${})", "amount": 75, "is_voided": false, "entered_at": "2026-08-11T17:30:56.071Z", "session_id": 4, "void_reason": null}, {"id": 68, "note": "USSD (*580#) Op: 18707538 | Phone: (0561351086)", "amount": 100, "is_voided": false, "entered_at": "2026-08-11T17:32:03.766Z", "session_id": 4, "void_reason": null}, {"id": 69, "note": "USSD (*585#) Bundle | Phone: (0549824391)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-11T17:33:36.036Z", "session_id": 4, "void_reason": null}, {"id": 73, "note": "Manual POS Entry | Phone: (${})", "amount": 2000, "is_voided": false, "entered_at": "2026-08-11T17:51:26.437Z", "session_id": 4, "void_reason": null}, {"id": 74, "note": "Manual POS Entry | Phone: (${})", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T17:55:10.224Z", "session_id": 4, "void_reason": null}, {"id": 77, "note": "USSD (*585#) Bundle | Phone: (0553210989)", "amount": 1220, "is_voided": false, "entered_at": "2026-08-11T18:24:16.407Z", "session_id": 4, "void_reason": null}, {"id": 79, "note": "USSD (*585#) Bundle | Phone: (0564027762)", "amount": 200, "is_voided": false, "entered_at": "2026-08-11T18:49:56.613Z", "session_id": 4, "void_reason": null}, {"id": 80, "note": "USSD (*580#) Op: 18992838 | Phone: (0564673234)", "amount": 150, "is_voided": false, "entered_at": "2026-08-11T18:53:36.989Z", "session_id": 4, "void_reason": null}, {"id": 81, "note": "USSD (*585#) Bundle | Phone: (0551237532)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-11T18:54:35.586Z", "session_id": 4, "void_reason": null}, {"id": 82, "note": "USSD (*585#) Bundle | Phone: (0550410322)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-11T19:25:03.158Z", "session_id": 4, "void_reason": null}, {"id": 83, "note": "USSD (*580#) Op: 220589612201 | Phone: (0561427799)", "amount": 1600, "is_voided": false, "entered_at": "2026-08-11T19:49:13.441Z", "session_id": 4, "void_reason": null}, {"id": 84, "note": "USSD (*585#) Bundle | Phone: (0553902614)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-11T20:11:27.051Z", "session_id": 4, "void_reason": null}], "sim_units_sold": 11, "accessory_sales": [], "sim_total_points": 10725, "sim_total_profit": 4125, "accessories_total": 0, "sim_total_commission": 550, "sim_total_real_price": 23000, "total_cashier_benefit": 550, "expected_register_cash": 29874, "sim_total_selling_price": 16400, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}], "global_pool": {"updated_at": "2026-08-11T20:48:08.133Z", "available_bonus": 113996.55, "available_points": 40625, "available_balance": 246753.54}}	0.00	0.00
3	2026-08-11	2	1	2026-08-11 22:52:20.113363+02	24	53000.00	28200.00	25675	13595.00	0.00	0.00	1200.00	1339.88	{"register": {"updated_at": "2026-08-11T20:51:17.837Z", "cash_amount": 41795}, "sessions": [{"debts": [], "store_id": 2, "sim_sales": [{"id": 17, "sold_at": "2026-08-11T07:59:41.789Z", "offer_id": 20, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 18, "sold_at": "2026-08-11T08:00:07.503Z", "offer_id": 20, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 19, "sold_at": "2026-08-11T08:07:23.303Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 20, "sold_at": "2026-08-11T08:31:54.037Z", "offer_id": 20, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 23, "sold_at": "2026-08-11T09:02:24.074Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 24, "sold_at": "2026-08-11T09:02:39.448Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 25, "sold_at": "2026-08-11T09:02:55.510Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 27, "sold_at": "2026-08-11T09:44:01.609Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 28, "sold_at": "2026-08-11T10:17:02.947Z", "offer_id": 18, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 375, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1500", "real_price_snapshot": 1500, "selling_price_snapshot": 1500}, {"id": 29, "sold_at": "2026-08-11T10:17:20.656Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 30, "sold_at": "2026-08-11T10:17:39.426Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 32, "sold_at": "2026-08-11T10:40:33.092Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 33, "sold_at": "2026-08-11T10:40:49.669Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 34, "sold_at": "2026-08-11T10:41:03.089Z", "offer_id": 7, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 35, "sold_at": "2026-08-11T10:49:33.680Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 36, "sold_at": "2026-08-11T10:53:43.102Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 40, "sold_at": "2026-08-11T12:29:21.543Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}, {"id": 41, "sold_at": "2026-08-11T13:37:33.994Z", "offer_id": 16, "is_voided": false, "session_id": 5, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1250}], "cashier_id": 5, "debt_total": 0, "session_id": 5, "store_name": "Kiosque Ain Meraine", "storm_total": 7720, "cashier_name": "Hadil", "opening_cash": 0, "session_date": "2026-08-10T22:00:00.000Z", "storm_entries": [{"id": 30, "note": "Manual POS Entry | Phone: (${})", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T07:44:56.874Z", "session_id": 5, "void_reason": null}, {"id": 35, "note": "Manual POS Entry | Phone: (${})", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T08:22:16.706Z", "session_id": 5, "void_reason": null}, {"id": 36, "note": "Manual POS Entry | Phone: (${})", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T08:43:22.558Z", "session_id": 5, "void_reason": null}, {"id": 40, "note": "Manual POS Entry | Phone: (${})", "amount": 120, "is_voided": false, "entered_at": "2026-08-11T09:08:18.062Z", "session_id": 5, "void_reason": null}, {"id": 52, "note": "Manual POS Entry | Phone: (${})", "amount": 2000, "is_voided": false, "entered_at": "2026-08-11T10:16:39.384Z", "session_id": 5, "void_reason": null}, {"id": 54, "note": "Manual POS Entry | Phone: (${})", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T11:06:59.104Z", "session_id": 5, "void_reason": null}, {"id": 55, "note": "Manual POS Entry | Phone: (${})", "amount": 2000, "is_voided": false, "entered_at": "2026-08-11T11:12:47.638Z", "session_id": 5, "void_reason": null}, {"id": 57, "note": "Manual POS Entry | Phone: (${})", "amount": 100, "is_voided": false, "entered_at": "2026-08-11T11:44:25.932Z", "session_id": 5, "void_reason": null}], "sim_units_sold": 18, "accessory_sales": [], "sim_total_points": 20475, "sim_total_profit": 475, "accessories_total": 0, "sim_total_commission": 900, "sim_total_real_price": 42000, "total_cashier_benefit": 900, "expected_register_cash": 41795, "sim_total_selling_price": 22000, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}, {"debts": [], "store_id": 2, "sim_sales": [{"id": 44, "sold_at": "2026-08-11T17:05:18.580Z", "offer_id": 7, "is_voided": false, "session_id": 7, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 47, "sold_at": "2026-08-11T17:43:12.129Z", "offer_id": 16, "is_voided": false, "session_id": 7, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1300}, {"id": 50, "sold_at": "2026-08-11T18:32:22.066Z", "offer_id": 7, "is_voided": false, "session_id": 7, "void_reason": null, "points_snapshot": 100, "commission_snapshot": 50, "offer_name_snapshot": "Ooredoo 500", "real_price_snapshot": 500, "selling_price_snapshot": 500}, {"id": 51, "sold_at": "2026-08-11T18:37:58.667Z", "offer_id": 16, "is_voided": false, "session_id": 7, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1300}, {"id": 58, "sold_at": "2026-08-11T20:32:42.897Z", "offer_id": 16, "is_voided": false, "session_id": 7, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1300}, {"id": 59, "sold_at": "2026-08-11T20:35:56.538Z", "offer_id": 16, "is_voided": false, "session_id": 7, "void_reason": null, "points_snapshot": 1250, "commission_snapshot": 50, "offer_name_snapshot": "Dima 2500", "real_price_snapshot": 2500, "selling_price_snapshot": 1300}], "cashier_id": 4, "debt_total": 0, "session_id": 7, "store_name": "Kiosque Ain Meraine", "storm_total": 5875, "cashier_name": "Aziz", "opening_cash": 29720, "session_date": "2026-08-10T22:00:00.000Z", "storm_entries": [{"id": 70, "note": "Manual POS Entry | Phone: (${})", "amount": 1000, "is_voided": false, "entered_at": "2026-08-11T17:43:35.175Z", "session_id": 7, "void_reason": null}, {"id": 71, "note": "Manual POS Entry | Phone: (${})", "amount": 500, "is_voided": false, "entered_at": "2026-08-11T17:43:49.461Z", "session_id": 7, "void_reason": null}, {"id": 72, "note": "Manual POS Entry | Phone: (${})", "amount": 1500, "is_voided": true, "entered_at": "2026-08-11T17:44:01.988Z", "session_id": 7, "void_reason": "fffff"}, {"id": 75, "note": "Manual POS Entry | Phone: (${})", "amount": 2075, "is_voided": false, "entered_at": "2026-08-11T18:07:26.880Z", "session_id": 7, "void_reason": null}, {"id": 76, "note": "Manual POS Entry | Phone: (${})", "amount": 1750, "is_voided": false, "entered_at": "2026-08-11T18:18:27.705Z", "session_id": 7, "void_reason": null}, {"id": 78, "note": "Manual POS Entry | Phone: (${})", "amount": 550, "is_voided": false, "entered_at": "2026-08-11T18:40:38.887Z", "session_id": 7, "void_reason": null}], "sim_units_sold": 6, "accessory_sales": [], "sim_total_points": 5200, "sim_total_profit": 400, "accessories_total": 0, "sim_total_commission": 300, "sim_total_real_price": 11000, "total_cashier_benefit": 300, "expected_register_cash": 41795, "sim_total_selling_price": 6200, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}], "global_pool": {"updated_at": "2026-08-11T20:48:08.133Z", "available_bonus": 113996.55, "available_points": 40625, "available_balance": 246753.54}}	0.00	0.00
4	2026-08-24	1	1	2026-08-26 17:01:49.009088+02	315	315000.00	315000.00	78750	475650.00	17325000.00	0.00	42750.00	685766.25	{"register": {"updated_at": "2026-08-26T14:32:12.037Z", "cash_amount": 57500}, "sessions": [{"debts": [], "store_id": 1, "sim_sales": [{"id": 62, "sold_at": "2026-08-24T19:02:55.106Z", "offer_id": 17, "is_voided": false, "session_id": 8, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "commission_points_snapshot": 250}, {"id": 63, "sold_at": "2026-08-24T20:49:09.500Z", "offer_id": 17, "is_voided": false, "session_id": 8, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "commission_points_snapshot": 250}, {"id": 64, "sold_at": "2026-08-24T21:13:40.014Z", "offer_id": 17, "is_voided": false, "session_id": 8, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "commission_points_snapshot": 250}], "cashier_id": 2, "debt_total": 0, "session_id": 8, "store_name": "AAO Sobha", "storm_total": 475650, "cashier_name": "Aymen", "opening_cash": 0, "session_date": "2026-08-23T22:00:00.000Z", "storm_entries": [{"id": 85, "note": "Storm Recharge", "amount": 2000, "is_voided": false, "entered_at": "2026-08-24T18:03:03.431Z", "session_id": 8, "void_reason": null}, {"id": 86, "note": "Storm", "amount": 1500, "is_voided": false, "entered_at": "2026-08-24T18:18:47.455Z", "session_id": 8, "void_reason": null}, {"id": 87, "note": "000000", "amount": 2000, "is_voided": false, "entered_at": "2026-08-24T18:59:15.777Z", "session_id": 8, "void_reason": null}, {"id": 88, "note": "000000", "amount": 2500, "is_voided": false, "entered_at": "2026-08-24T19:02:32.742Z", "session_id": 8, "void_reason": null}, {"id": 89, "note": "Manual POS Entry | Phone: (${})", "amount": 1000, "is_voided": false, "entered_at": "2026-08-24T19:07:03.270Z", "session_id": 8, "void_reason": null}, {"id": 90, "note": "Manual POS Entry | Phone: (000000)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-24T19:10:17.966Z", "session_id": 8, "void_reason": null}, {"id": 91, "note": "Manual POS Entry | Phone: (000000)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-24T19:17:00.861Z", "session_id": 8, "void_reason": null}, {"id": 92, "note": "Manual POS Entry | Phone: (000000)", "amount": 1000, "is_voided": false, "entered_at": "2026-08-24T19:17:54.800Z", "session_id": 8, "void_reason": null}, {"id": 93, "note": "Manual POS Entry | Phone: (000000)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-24T19:20:13.110Z", "session_id": 8, "void_reason": null}, {"id": 94, "note": "Manual POS Entry | Phone: (000000)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-24T19:23:35.893Z", "session_id": 8, "void_reason": null}, {"id": 95, "note": "Manual POS Entry | Phone: (0559516395)", "amount": 2500, "is_voided": false, "entered_at": "2026-08-24T19:47:37.208Z", "session_id": 8, "void_reason": null}, {"id": 96, "note": "Manual POS Entry | Phone: (0559516395)", "amount": 1550, "is_voided": false, "entered_at": "2026-08-24T19:47:51.420Z", "session_id": 8, "void_reason": null}, {"id": 97, "note": "Manual POS Entry | Phone: (0559516395)", "amount": 100, "is_voided": false, "entered_at": "2026-08-24T19:48:11.738Z", "session_id": 8, "void_reason": null}, {"id": 98, "note": "Manual POS Entry | Phone: (0559516395)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-24T20:49:34.739Z", "session_id": 8, "void_reason": null}, {"id": 99, "note": "Manual POS Entry | Phone: (0559516359)", "amount": 1500, "is_voided": false, "entered_at": "2026-08-24T21:19:32.682Z", "session_id": 8, "void_reason": null}], "sim_units_sold": 315, "accessory_sales": [{"id": 1, "sold_at": "2026-08-24T19:45:30.086Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 0, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}, {"id": 2, "sold_at": "2026-08-24T20:49:48.612Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}, {"id": 3, "sold_at": "2026-08-24T20:50:02.509Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}, {"id": 4, "sold_at": "2026-08-24T20:50:08.801Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}, {"id": 5, "sold_at": "2026-08-24T20:50:15.904Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}, {"id": 6, "sold_at": "2026-08-24T20:50:27.890Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}, {"id": 7, "sold_at": "2026-08-24T21:15:52.700Z", "is_voided": false, "product_id": 1, "session_id": 8, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones"}], "sim_total_points": 78750, "sim_total_profit": 78750, "accessories_total": 17325000, "sim_total_commission": 15750, "sim_total_real_price": 315000, "total_cashier_benefit": 42750, "expected_register_cash": 18115650, "sim_total_selling_price": 315000, "accessories_total_profit": 630000, "accessories_total_commission": 27000, "accessories_total_real_price": 16695000}], "global_pool": {"updated_at": "2026-08-26T14:39:55.302Z", "available_bonus": 13786.55, "available_points": 1250, "available_balance": 12191.54}}	0.00	0.00
5	2026-08-09	1	1	2026-08-26 17:20:26.921813+02	0	0.00	0.00	0	0.00	0.00	0.00	0.00	0.00	{"register": {"updated_at": "2026-08-26T14:32:12.037Z", "cash_amount": 57500}, "sessions": [{"debts": [], "store_id": 1, "sim_sales": [], "cashier_id": 2, "debt_total": 0, "session_id": 1, "store_name": "AAO Sobha", "storm_total": 0, "cashier_name": "Aymen", "opening_cash": 0, "session_date": "2026-08-08T22:00:00.000Z", "storm_entries": [], "sim_units_sold": 0, "accessory_sales": [], "sim_total_points": 0, "sim_total_profit": 0, "accessories_total": 0, "sim_total_commission": 0, "sim_total_real_price": 0, "total_cashier_benefit": 0, "expected_register_cash": 0, "loyalty_driven_revenue": 0, "loyalty_points_redeemed": 0, "sim_total_selling_price": 0, "accessories_total_profit": 0, "accessories_total_commission": 0, "accessories_total_real_price": 0}], "global_pool": {"updated_at": "2026-08-26T14:39:55.302Z", "available_bonus": 13786.55, "available_points": 1250, "available_balance": 12191.54}}	0.00	0.00
6	2026-08-25	1	1	2026-08-26 18:19:18.097285+02	30	30000.00	30000.00	7500	781275.00	1650000.00	0.00	4500.00	87781.88	{"register": {"updated_at": "2026-08-26T14:32:12.037Z", "cash_amount": 57500}, "sessions": [{"debts": [], "store_id": 1, "sim_sales": [{"id": 65, "sold_at": "2026-08-25T17:39:12.773Z", "offer_id": 17, "is_voided": false, "session_id": 9, "customer_id": 50, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "loyalty_earned_snapshot": 25, "loyalty_redeemed_snapshot": 0, "commission_points_snapshot": 250}, {"id": 66, "sold_at": "2026-08-25T19:27:27.074Z", "offer_id": 17, "is_voided": false, "session_id": 9, "customer_id": 50, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "loyalty_earned_snapshot": 25, "loyalty_redeemed_snapshot": 0, "commission_points_snapshot": 250}, {"id": 67, "sold_at": "2026-08-25T19:36:42.444Z", "offer_id": 17, "is_voided": false, "session_id": 9, "customer_id": 50, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "loyalty_earned_snapshot": 25, "loyalty_redeemed_snapshot": 0, "commission_points_snapshot": 250}, {"id": 68, "sold_at": "2026-08-25T19:49:37.576Z", "offer_id": 17, "is_voided": false, "session_id": 9, "customer_id": 50, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "loyalty_earned_snapshot": 25, "loyalty_redeemed_snapshot": 0, "commission_points_snapshot": 250}, {"id": 69, "sold_at": "2026-08-26T14:29:26.199Z", "offer_id": 17, "is_voided": false, "session_id": 9, "customer_id": 52, "void_reason": null, "commission_snapshot": 50, "offer_name_snapshot": "La Gold 1000", "real_price_snapshot": 1000, "selling_price_snapshot": 1000, "loyalty_earned_snapshot": 25, "loyalty_redeemed_snapshot": 0, "commission_points_snapshot": 250}], "cashier_id": 2, "debt_total": 0, "session_id": 9, "store_name": "AAO Sobha", "storm_total": 781275, "cashier_name": "Aymen", "opening_cash": 0, "session_date": "2026-08-24T22:00:00.000Z", "storm_entries": [{"id": 100, "note": null, "amount": 1000, "is_voided": false, "entered_at": "2026-08-25T15:01:33.512Z", "session_id": 9, "customer_id": 51, "void_reason": null, "loyalty_earned_snapshot": 10, "loyalty_redeemed_snapshot": 0}, {"id": 101, "note": null, "amount": 150000, "is_voided": false, "entered_at": "2026-08-25T15:02:17.587Z", "session_id": 9, "customer_id": 51, "void_reason": null, "loyalty_earned_snapshot": 1500, "loyalty_redeemed_snapshot": 0}, {"id": 102, "note": null, "amount": 755, "is_voided": false, "entered_at": "2026-08-25T15:02:47.093Z", "session_id": 9, "customer_id": 51, "void_reason": null, "loyalty_earned_snapshot": 7.55, "loyalty_redeemed_snapshot": 1510}, {"id": 103, "note": null, "amount": 1500, "is_voided": false, "entered_at": "2026-08-25T17:35:46.362Z", "session_id": 9, "customer_id": 50, "void_reason": null, "loyalty_earned_snapshot": 15, "loyalty_redeemed_snapshot": 0}, {"id": 104, "note": null, "amount": 1500, "is_voided": false, "entered_at": "2026-08-25T17:37:22.055Z", "session_id": 9, "customer_id": 50, "void_reason": null, "loyalty_earned_snapshot": 15, "loyalty_redeemed_snapshot": 0}, {"id": 105, "note": null, "amount": 1500, "is_voided": false, "entered_at": "2026-08-26T14:30:42.232Z", "session_id": 9, "customer_id": 53, "void_reason": null, "loyalty_earned_snapshot": 15, "loyalty_redeemed_snapshot": 0}], "sim_units_sold": 30, "accessory_sales": [{"id": 8, "sold_at": "2026-08-26T14:32:12.037Z", "is_voided": false, "product_id": 1, "session_id": 9, "customer_id": 54, "void_reason": null, "price_snapshot": 55000, "commission_snapshot": 100, "real_price_snapshot": 53000, "product_name_snapshot": "Samsung Galaxy A56 5G 8/128", "category_name_snapshot": "Samsung phones", "loyalty_earned_snapshot": 100, "loyalty_redeemed_snapshot": 0}], "sim_total_points": 7500, "sim_total_profit": 7500, "accessories_total": 1650000, "sim_total_commission": 1500, "sim_total_real_price": 30000, "total_cashier_benefit": 4500, "expected_register_cash": 2461275, "loyalty_driven_revenue": 2461275, "loyalty_points_redeemed": 7550, "sim_total_selling_price": 30000, "accessories_total_profit": 60000, "accessories_total_commission": 3000, "accessories_total_real_price": 1590000}], "global_pool": {"updated_at": "2026-08-26T14:39:55.302Z", "available_bonus": 13786.55, "available_points": 1250, "available_balance": 12191.54}}	7550.00	2461275.00
\.


--
-- TOC entry 5438 (class 0 OID 17152)
-- Dependencies: 244
-- Data for Name: global_pool_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.global_pool_state (id, available_balance, available_bonus, available_points, updated_at, updated_by, notes) FROM stdin;
1	145140.54	120746.55	26125	2026-08-09 20:31:49.09263+02	1	[SYNC] Manual Sync via Ooredoo USSD
2	139640.54	143471.55	0	2026-08-09 23:37:06.710816+02	1	[SYNC] Manual Sync via Ooredoo USSD
3	139640.54	143471.55	0	2026-08-10 06:00:03.592778+02	1	[SNAPSHOT] Daily Opening Balance
4	139065.54	143471.55	0	2026-08-10 09:07:37.438397+02	1	[SYNC] Manual Sync via Ooredoo USSD
5	139065.54	141471.55	0	2026-08-10 09:29:44.584936+02	1	[SYNC] Manual Sync via Ooredoo USSD
6	138565.54	139371.55	100	2026-08-10 09:46:59.953309+02	1	[SYNC] Manual Sync via Ooredoo USSD
7	136065.54	139371.55	1350	2026-08-10 10:02:37.138892+02	1	[SYNC] Manual Sync via Ooredoo USSD
8	132167.54	139371.55	2600	2026-08-10 10:08:51.131208+02	1	[SYNC] Manual Sync via Ooredoo USSD
9	125167.54	137871.55	5600	2026-08-10 10:19:50.967223+02	1	[SYNC] Manual Sync via Ooredoo USSD
10	122492.54	137871.55	5975	2026-08-10 10:38:10.276494+02	1	[SYNC] Manual Sync via Ooredoo USSD
11	121992.54	134531.55	6075	2026-08-10 11:11:36.453592+02	1	[SYNC] Manual Sync via Ooredoo USSD
12	84427.54	120841.55	22525	2026-08-10 18:11:14.256557+02	1	[SYNC] Manual Sync via Ooredoo USSD
13	81927.54	120841.55	23775	2026-08-10 19:36:03.23846+02	1	[SYNC] Manual Sync via Ooredoo USSD
14	77882.54	118991.55	25025	2026-08-10 20:03:19.430131+02	1	[SYNC] Manual Sync via Ooredoo USSD
15	77882.54	118991.55	25025	2026-08-10 20:03:27.397771+02	1	[PRE-CONVERSION] Snapshot
16	77882.54	144016.55	0	2026-08-10 20:03:32.192188+02	1	[POST-CONVERSION] Auto-Synced via *582#
17	77882.54	144016.55	0	2026-08-10 20:03:32.19438+02	1	[CONVERSION] Converted 25025 pts into 25025.00 DZD.
18	74882.54	140316.55	1350	2026-08-10 20:45:15.423005+02	1	[SYNC] Manual Sync via Ooredoo USSD
19	71637.54	140316.55	2600	2026-08-10 21:20:20.571836+02	1	[SYNC] Manual Sync via Ooredoo USSD
20	69137.54	140316.55	3850	2026-08-10 22:58:18.282942+02	1	[PRE-CONVERSION] Snapshot
21	69137.54	144166.55	0	2026-08-10 22:59:02.751606+02	1	[SYNC] Manual Sync via Ooredoo USSD
22	69137.54	144166.55	0	2026-08-10 22:59:10.607227+02	1	[PRE-CONVERSION] Snapshot
23	69137.54	144166.55	0	2026-08-11 06:00:05.004704+02	1	[SNAPSHOT] Daily Opening Balance
24	60441.54	143666.55	2500	2026-08-11 10:01:55.571467+02	1	[SYNC] Manual Sync via Ooredoo USSD
25	51343.54	141466.55	6250	2026-08-11 10:41:21.767674+02	1	[SYNC] Manual Sync via Ooredoo USSD
26	34448.54	135646.55	12875	2026-08-11 11:56:03.053504+02	1	[SYNC] Manual Sync via Ooredoo USSD
27	34448.54	135646.55	12875	2026-08-11 11:56:43.75509+02	1	[SYNC] Manual Sync via Ooredoo USSD
28	34448.54	135646.55	12875	2026-08-11 11:58:53.588501+02	1	[SYNC] Manual Sync via Ooredoo USSD
29	16948.54	131446.55	20850	2026-08-11 12:48:30.22432+02	1	[SYNC] Manual Sync via Ooredoo USSD
30	16948.54	131446.55	20850	2026-08-11 12:48:48.254598+02	1	[SYNC] Manual Sync via Ooredoo USSD
31	2248.54	126446.55	27100	2026-08-11 16:50:27.315014+02	1	[SYNC] Manual Sync via Ooredoo USSD
32	284018.54	126446.55	27100	2026-08-11 17:51:03.036513+02	1	[SYNC] Manual Sync via Ooredoo USSD
33	283518.54	126446.55	27200	2026-08-11 18:37:08.433365+02	1	[SYNC] Manual Sync via Ooredoo USSD
34	283518.54	125946.55	27200	2026-08-11 18:39:25.512814+02	1	[SYNC] Manual Sync via Ooredoo USSD
35	283018.54	124446.55	27300	2026-08-11 19:10:53.936396+02	1	[SYNC] Manual Sync via Ooredoo USSD
36	283018.54	124446.55	27300	2026-08-11 19:11:29.86959+02	1	[RECHARGE] 300000 | Storm
37	283018.54	122946.55	27300	2026-08-11 19:19:49.724076+02	1	[SYNC] Manual Sync via Ooredoo USSD
38	283018.54	122946.55	27300	2026-08-11 19:23:03.270369+02	1	[SYNC] Manual Sync via Ooredoo USSD
39	279018.54	122946.55	28925	2026-08-11 19:29:11.796377+02	1	[SYNC] Manual Sync via Ooredoo USSD
40	278443.54	121346.55	28925	2026-08-11 19:34:03.169685+02	1	[SYNC] Manual Sync via Ooredoo USSD
41	278443.54	121346.55	28925	2026-08-11 19:37:21.618112+02	1	[SYNC] Manual Sync via Ooredoo USSD
42	275943.54	121346.55	30175	2026-08-11 19:45:08.596835+02	1	[SYNC] Manual Sync via Ooredoo USSD
43	275943.54	121346.55	30175	2026-08-11 19:46:27.784152+02	1	[SYNC] Manual Sync via Ooredoo USSD
44	275943.54	121346.55	30175	2026-08-11 19:49:08.748766+02	1	[SYNC] Manual Sync via Ooredoo USSD
45	275943.54	118846.55	30175	2026-08-11 19:55:40.24528+02	1	[SYNC] Manual Sync via Ooredoo USSD
46	268398.54	118846.55	31425	2026-08-11 20:29:46.778177+02	1	[SYNC] Manual Sync via Ooredoo USSD
47	267898.54	118846.55	31525	2026-08-11 20:36:12.251075+02	1	[SYNC] Manual Sync via Ooredoo USSD
48	258853.54	116996.55	35525	2026-08-11 21:03:08.695771+02	1	[SYNC] Manual Sync via Ooredoo USSD
49	251753.54	115496.55	38125	2026-08-11 21:50:47.889995+02	1	[SYNC] Manual Sync via Ooredoo USSD
50	251753.54	113996.55	38125	2026-08-11 22:29:09.76527+02	1	[SYNC] Manual Sync via Ooredoo USSD
51	251753.54	113996.55	38125	2026-08-11 22:30:44.71041+02	1	[SYNC] Manual Sync via Ooredoo USSD
52	249253.54	113996.55	39375	2026-08-11 22:32:48.359364+02	1	[SYNC] Manual Sync via Ooredoo USSD
53	246753.54	113996.55	40625	2026-08-11 22:40:03.827501+02	1	[SYNC] Manual Sync via Ooredoo USSD
54	246753.54	113996.55	40625	2026-08-11 22:47:38.583875+02	1	[SYNC] Manual Sync via Ooredoo USSD
55	246753.54	113996.55	40625	2026-08-11 22:48:08.13367+02	1	[SYNC] Manual Sync via Ooredoo USSD
56	205429.54	20476.55	1475	2026-08-23 18:36:02.664408+02	1	[SYNC] Manual Sync via Ooredoo USSD
57	198974.54	14101.55	0	2026-08-24 06:00:04.150095+02	1	[SNAPSHOT] Daily Opening Balance
58	153054.54	6351.55	6625	2026-08-24 18:09:12.587964+02	1	[SYNC] Manual Sync via Ooredoo USSD
59	150554.54	6351.55	7875	2026-08-24 18:15:33.924471+02	1	[SYNC] Manual Sync via Ooredoo USSD
60	150554.54	6351.55	7875	2026-08-24 18:15:43.175116+02	1	[PRE-CONVERSION] Snapshot
61	150554.54	14226.55	0	2026-08-24 18:15:48.151773+02	1	[POST-CONVERSION] Auto-Synced via *582#
62	150554.54	14226.55	0	2026-08-24 18:15:48.153424+02	1	[CONVERSION] Converted 7875 pts into 7875.00 DZD.
63	119604.54	13626.55	0	2026-08-25 06:00:03.557687+02	1	[SNAPSHOT] Daily Opening Balance
64	73176.54	526.55	18275	2026-08-25 16:48:37.805792+02	1	[SYNC] Manual Sync via Ooredoo USSD
65	73176.54	526.55	18275	2026-08-25 16:48:56.042692+02	1	[PRE-CONVERSION] Snapshot
66	73176.54	18801.55	0	2026-08-25 16:49:00.927287+02	1	[POST-CONVERSION] Auto-Synced via *582#
67	73176.54	18801.55	0	2026-08-25 16:49:00.929862+02	1	[CONVERSION] Converted 18275 pts into 18275.00 DZD.
68	58216.54	5886.55	0	2026-08-26 06:00:06.429888+02	1	[SNAPSHOT] Daily Opening Balance
69	12191.54	13786.55	1250	2026-08-26 16:39:55.302711+02	1	[SYNC] Manual Sync via Ooredoo USSD
70	506.54	4661.55	0	2026-08-27 06:00:04.191809+02	1	[SNAPSHOT] Daily Opening Balance
71	197176.54	10536.55	0	2026-08-28 06:00:09.334876+02	1	[SNAPSHOT] Daily Opening Balance
72	187901.54	5236.55	4825	2026-08-29 06:00:03.716031+02	1	[SNAPSHOT] Daily Opening Balance
\.


--
-- TOC entry 5455 (class 0 OID 66927)
-- Dependencies: 263
-- Data for Name: loyalty_ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loyalty_ledger (id, customer_id, points, transaction_type, description, created_at) FROM stdin;
21	50	-681.00	spend	Redeemed points	2026-08-24 23:13:40.01453+02
22	50	25.00	earn	Earned from sim purchase	2026-08-24 23:13:40.01453+02
23	1	-200.00	spend	Redeemed points	2026-08-24 23:15:52.700642+02
24	1	100.00	earn	Earned from accessory purchase	2026-08-24 23:15:52.700642+02
25	1	-250.00	spend	Redeemed points	2026-08-24 23:19:32.682417+02
26	1	15.00	earn	Earned from storm purchase	2026-08-24 23:19:32.682417+02
27	51	10.00	earn	Earned from storm purchase	2026-08-25 17:01:33.512+02
28	51	1500.00	earn	Earned from storm purchase	2026-08-25 17:02:17.587947+02
29	51	-1510.00	spend	Redeemed points	2026-08-25 17:02:47.093121+02
30	51	7.55	earn	Earned from storm purchase	2026-08-25 17:02:47.093121+02
31	51	50.00	manual_adjustment	Manual Adjustment: Apologie for a mistake	2026-08-25 18:48:07.426336+02
32	1	-50.00	manual_adjustment	Manual Adjustment: trying to stell a cable	2026-08-25 18:56:03.133825+02
33	50	15.00	earn	Earned from storm purchase	2026-08-25 19:35:46.362146+02
34	50	15.00	earn	Earned from storm purchase	2026-08-25 19:37:22.055433+02
35	50	25.00	earn	Earned from sim purchase	2026-08-25 19:39:12.773155+02
36	50	25.00	earn	Earned from sim purchase	2026-08-25 21:27:27.074981+02
37	50	25.00	earn	Earned from sim purchase	2026-08-25 21:36:42.444397+02
38	50	25.00	earn	Earned from sim purchase	2026-08-25 21:49:37.576378+02
39	52	25.00	earn	Earned from sim purchase	2026-08-26 16:29:26.199716+02
40	53	15.00	earn	Earned from storm purchase	2026-08-26 16:30:42.232669+02
41	54	100.00	earn	Earned from accessory purchase	2026-08-26 16:32:12.037643+02
42	50	25.00	earn	Earned from sim purchase	2026-08-26 21:01:37.151991+02
43	1	-1000.00	spend	Redeemed points	2026-08-26 21:02:58.848808+02
44	1	25.00	earn	Earned from sim purchase	2026-08-26 21:02:58.848808+02
45	51	50.00	manual_adjustment	Manual Adjustment: 00000	2026-08-26 21:12:47.156657+02
\.


--
-- TOC entry 5453 (class 0 OID 66909)
-- Dependencies: 261
-- Data for Name: loyalty_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loyalty_settings (key, value, description) FROM stdin;
storm_earn_percent	1	Percentage of Storm DZD converted to points
point_to_dzd_value	1	Cash value of 1 point in DZD
min_points_to_redeem	600	Minimum points required before a client can spend them
visit_bonus_points	25	Bonus points for returning in the same month
visit_bonus_min_spend	2000	Minimum DA spend required to trigger the visit bonus
referral_bonus_points	25	Points awarded to veteran client when a referral makes their first purchase
expiry_days	90	Days of inactivity before points expire
tier_bronze	250	Lifetime points needed for Bronze
tier_silver	500	Lifetime points needed for Silver
tier_gold	1000	Lifetime points needed for Gold
tier_vip	2000	Lifetime points needed for VIP
tier_vvip	4000	Lifetime points needed for VVIP
\.


--
-- TOC entry 5446 (class 0 OID 17419)
-- Dependencies: 254
-- Data for Name: offer_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.offer_categories (id, name, sort_order, is_active, created_at) FROM stdin;
1	Gold	1	t	2026-08-09 20:01:08.487617+02
2	N'yooz	2	t	2026-08-09 20:01:08.487617+02
3	Dima Ooredoo	3	t	2026-08-09 20:01:08.487617+02
4	Ooredoo	4	t	2026-08-09 20:01:08.487617+02
5	Ooredoo POP	5	t	2026-08-09 20:01:08.487617+02
6	Ooredoo Internet	6	t	2026-08-09 20:01:08.487617+02
7	test	0	t	2026-08-24 22:29:38.474887+02
\.


--
-- TOC entry 5422 (class 0 OID 16892)
-- Dependencies: 228
-- Data for Name: offers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.offers (id, name, real_price, selling_price, commission_points, commission_amount, low_stock_threshold, is_active, sort_order, created_at, updated_at, category_id, loyalty_points) FROM stdin;
13	Dima 500	500.00	500.00	0	50.00	5	t	0	2026-08-09 21:31:20.53602+02	2026-08-09 21:31:20.53602+02	3	0.00
21	N'YOOZ 300	300.00	300.00	0	50.00	5	t	0	2026-08-09 21:34:17.832067+02	2026-08-09 21:34:17.832067+02	2	0.00
22	N'YOOZ 500	500.00	500.00	0	50.00	5	t	0	2026-08-09 21:34:27.675434+02	2026-08-09 21:34:27.675434+02	2	0.00
30	test	1000.00	1000.00	0	0.00	5	f	0	2026-08-24 22:30:24.627654+02	2026-08-24 22:34:42.091661+02	7	0.00
17	La Gold 1000	1000.00	1000.00	250	50.00	5	t	0	2026-08-09 21:32:43.026683+02	2026-08-24 22:42:54.080204+02	1	25.00
18	La Gold 1500	1500.00	1500.00	375	50.00	5	t	0	2026-08-09 21:32:53.921047+02	2026-08-24 22:43:03.685649+02	1	25.00
19	La Gold 2000	2000.00	2000.00	500	50.00	5	t	0	2026-08-09 21:33:15.933372+02	2026-08-24 22:43:08.649391+02	1	25.00
20	La Gold 2500	2500.00	2500.00	1250	50.00	5	t	0	2026-08-09 21:33:29.523856+02	2026-08-24 22:43:12.18796+02	1	25.00
23	N'YOOZ 1000	1000.00	1000.00	250	50.00	5	t	0	2026-08-09 21:34:48.637281+02	2026-08-24 22:43:20.55429+02	2	25.00
24	N'YOOZ 1500	1500.00	1500.00	375	50.00	5	t	0	2026-08-09 21:35:04.610094+02	2026-08-24 22:43:24.154243+02	2	25.00
12	Dima 1200	1200.00	1200.00	300	50.00	5	t	0	2026-08-09 21:31:05.178195+02	2026-08-24 22:43:31.239862+02	3	25.00
14	Dima 1500	1500.00	1500.00	375	50.00	5	t	0	2026-08-09 21:31:36.791199+02	2026-08-24 22:43:35.923793+02	3	25.00
16	Dima 2500	2500.00	1700.00	1250	50.00	5	t	0	2026-08-09 21:32:19.892247+02	2026-08-24 22:43:41.46581+02	3	25.00
15	Dima 2000	2000.00	2000.00	500	50.00	5	t	0	2026-08-09 21:32:01.092223+02	2026-08-24 22:43:46.981798+02	3	25.00
8	2500 : Ooredoo 500 * 6	2500.00	2500.00	1125	50.00	5	t	0	2026-08-09 21:28:54.81982+02	2026-08-24 22:43:55.26725+02	4	25.00
9	3500 : Ooredoo 500 * 9	3500.00	3500.00	1050	50.00	5	t	0	2026-08-09 21:29:27.390151+02	2026-08-24 22:44:00.322738+02	4	25.00
10	4500 : Ooredoo 500 * 12	4500.00	4500.00	1350	50.00	5	t	0	2026-08-09 21:29:59.463641+02	2026-08-24 22:44:05.828649+02	4	25.00
11	4990 : 200Go + Ooredoo 500 * 12	4990.00	4990.00	1200	50.00	5	t	0	2026-08-09 21:30:31.336362+02	2026-08-24 22:44:10.943908+02	4	25.00
25	Ooredoo POP 1500	1500.00	1500.00	150	50.00	5	t	0	2026-08-09 21:35:38.45506+02	2026-08-24 22:45:07.876243+02	5	25.00
6	Ooredoo Internet 19500	19500.00	19500.00	3900	50.00	5	t	0	2026-08-09 21:27:53.748395+02	2026-08-24 22:45:13.686056+02	6	25.00
5	Ooredoo Internet 10000	10000.00	10000.00	2000	50.00	5	t	0	2026-08-09 21:27:35.838599+02	2026-08-24 22:45:46.228824+02	6	25.00
4	Ooredoo Internet 5500	5500.00	5500.00	1100	50.00	5	t	0	2026-08-09 21:27:15.405182+02	2026-08-24 22:45:50.323782+02	6	25.00
3	Ooredoo Internet 4500	4500.00	4500.00	900	50.00	5	t	0	2026-08-09 21:26:51.995533+02	2026-08-24 22:45:53.861265+02	6	25.00
2	Ooredoo Internet 2500	2500.00	2500.00	500	50.00	5	t	0	2026-08-09 21:26:30.345212+02	2026-08-24 22:45:57.414761+02	6	25.00
1	Ooredoo Internet 1500	1500.00	1500.00	150	50.00	5	t	0	2026-08-09 21:25:58.312802+02	2026-08-24 22:46:02.478679+02	6	25.00
29	Ooredoo POP 4000	4000.00	4000.00	1200	50.00	5	t	0	2026-08-09 21:36:53.827397+02	2026-08-24 22:46:06.455814+02	5	25.00
28	Ooredoo POP 2500	2500.00	2500.00	750	50.00	5	t	0	2026-08-09 21:36:38.163239+02	2026-08-24 22:46:10.310273+02	5	25.00
26	Ooredoo POP 2000	2000.00	2000.00	200	50.00	5	t	0	2026-08-09 21:35:55.762243+02	2026-08-24 22:46:18.373255+02	5	25.00
27	Ooredoo POP 2000 0550	2000.00	2000.00	0	50.00	5	t	0	2026-08-09 21:36:21.596018+02	2026-08-24 22:46:30.767833+02	5	0.00
7	Ooredoo 500	500.00	500.00	100	50.00	5	t	0	2026-08-09 21:28:22.84033+02	2026-08-24 22:46:41.24446+02	4	0.00
\.


--
-- TOC entry 5424 (class 0 OID 16922)
-- Dependencies: 230
-- Data for Name: product_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.product_categories (id, name, sort_order, created_at) FROM stdin;
1	Phones	1	2026-08-09 20:01:08.487617+02
2	PC Laptops	2	2026-08-09 20:01:08.487617+02
3	PC Desktops	3	2026-08-09 20:01:08.487617+02
4	Accessories	4	2026-08-09 20:01:08.487617+02
6	Samsung phones	0	2026-08-09 21:57:17.775009+02
\.


--
-- TOC entry 5426 (class 0 OID 16937)
-- Dependencies: 232
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (id, name, price, category_id, commission_amount, is_active, sort_order, created_at, updated_at, real_price, barcode, low_stock_threshold, loyalty_points) FROM stdin;
3	Test Product 2 (Batch 1786305714562)	1923.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1892.00	BARCODE-1786305714562-2	5	0.00
4	Test Product 3 (Batch 1786305714562)	1788.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	795.00	BARCODE-1786305714562-3	5	0.00
5	Test Product 4 (Batch 1786305714562)	2719.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2483.00	BARCODE-1786305714562-4	5	0.00
6	Test Product 5 (Batch 1786305714562)	1480.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	660.00	BARCODE-1786305714562-5	5	0.00
7	Test Product 6 (Batch 1786305714562)	3109.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2428.00	BARCODE-1786305714562-6	5	0.00
8	Test Product 7 (Batch 1786305714562)	3187.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2322.00	BARCODE-1786305714562-7	5	0.00
9	Test Product 8 (Batch 1786305714562)	2867.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1985.00	BARCODE-1786305714562-8	5	0.00
10	Test Product 9 (Batch 1786305714562)	3230.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2232.00	BARCODE-1786305714562-9	5	0.00
11	Test Product 10 (Batch 1786305714562)	1190.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1073.00	BARCODE-1786305714562-10	5	0.00
12	Test Product 11 (Batch 1786305714562)	2009.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1270.00	BARCODE-1786305714562-11	5	0.00
13	Test Product 12 (Batch 1786305714562)	3235.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2387.00	BARCODE-1786305714562-12	5	0.00
14	Test Product 13 (Batch 1786305714562)	1134.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	564.00	BARCODE-1786305714562-13	5	0.00
15	Test Product 14 (Batch 1786305714562)	2606.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2092.00	BARCODE-1786305714562-14	5	0.00
16	Test Product 15 (Batch 1786305714562)	1993.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1978.00	BARCODE-1786305714562-15	5	0.00
17	Test Product 16 (Batch 1786305714562)	1701.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	784.00	BARCODE-1786305714562-16	5	0.00
18	Test Product 17 (Batch 1786305714562)	2464.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2228.00	BARCODE-1786305714562-17	5	0.00
19	Test Product 18 (Batch 1786305714562)	1647.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1189.00	BARCODE-1786305714562-18	5	0.00
20	Test Product 19 (Batch 1786305714562)	2352.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2084.00	BARCODE-1786305714562-19	5	0.00
21	Test Product 20 (Batch 1786305714562)	1421.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1022.00	BARCODE-1786305714562-20	5	0.00
22	Test Product 21 (Batch 1786305714562)	3005.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2123.00	BARCODE-1786305714562-21	5	0.00
23	Test Product 22 (Batch 1786305714562)	2838.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2031.00	BARCODE-1786305714562-22	5	0.00
24	Test Product 23 (Batch 1786305714562)	2485.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1914.00	BARCODE-1786305714562-23	5	0.00
25	Test Product 24 (Batch 1786305714562)	1563.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1343.00	BARCODE-1786305714562-24	5	0.00
26	Test Product 25 (Batch 1786305714562)	1968.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1142.00	BARCODE-1786305714562-25	5	0.00
27	Test Product 26 (Batch 1786305714562)	2194.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2081.00	BARCODE-1786305714562-26	5	0.00
28	Test Product 27 (Batch 1786305714562)	1841.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1269.00	BARCODE-1786305714562-27	5	0.00
29	Test Product 28 (Batch 1786305714562)	2118.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1473.00	BARCODE-1786305714562-28	5	0.00
30	Test Product 29 (Batch 1786305714562)	2650.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2432.00	BARCODE-1786305714562-29	5	0.00
31	Test Product 30 (Batch 1786305714562)	1899.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1780.00	BARCODE-1786305714562-30	5	0.00
32	Test Product 31 (Batch 1786305714562)	1547.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	654.00	BARCODE-1786305714562-31	5	0.00
33	Test Product 32 (Batch 1786305714562)	2565.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2415.00	BARCODE-1786305714562-32	5	0.00
34	Test Product 33 (Batch 1786305714562)	2447.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1842.00	BARCODE-1786305714562-33	5	0.00
35	Test Product 34 (Batch 1786305714562)	2388.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1575.00	BARCODE-1786305714562-34	5	0.00
36	Test Product 35 (Batch 1786305714562)	1381.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	744.00	BARCODE-1786305714562-35	5	0.00
37	Test Product 36 (Batch 1786305714562)	2406.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1878.00	BARCODE-1786305714562-36	5	0.00
38	Test Product 37 (Batch 1786305714562)	1629.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	657.00	BARCODE-1786305714562-37	5	0.00
39	Test Product 38 (Batch 1786305714562)	3015.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2366.00	BARCODE-1786305714562-38	5	0.00
40	Test Product 39 (Batch 1786305714562)	960.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	507.00	BARCODE-1786305714562-39	5	0.00
41	Test Product 40 (Batch 1786305714562)	2106.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1518.00	BARCODE-1786305714562-40	5	0.00
42	Test Product 41 (Batch 1786305714562)	2494.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2389.00	BARCODE-1786305714562-41	5	0.00
43	Test Product 42 (Batch 1786305714562)	1651.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	943.00	BARCODE-1786305714562-42	5	0.00
44	Test Product 43 (Batch 1786305714562)	1360.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1307.00	BARCODE-1786305714562-43	5	0.00
45	Test Product 44 (Batch 1786305714562)	1069.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	583.00	BARCODE-1786305714562-44	5	0.00
46	Test Product 45 (Batch 1786305714562)	3030.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2081.00	BARCODE-1786305714562-45	5	0.00
47	Test Product 46 (Batch 1786305714562)	1632.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1249.00	BARCODE-1786305714562-46	5	0.00
48	Test Product 47 (Batch 1786305714562)	2361.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1748.00	BARCODE-1786305714562-47	5	0.00
49	Test Product 48 (Batch 1786305714562)	1388.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	603.00	BARCODE-1786305714562-48	5	0.00
50	Test Product 49 (Batch 1786305714562)	1908.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1478.00	BARCODE-1786305714562-49	5	0.00
51	Test Product 50 (Batch 1786305714562)	1453.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	751.00	BARCODE-1786305714562-50	5	0.00
52	Test Product 51 (Batch 1786305714562)	902.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	724.00	BARCODE-1786305714562-51	5	0.00
53	Test Product 52 (Batch 1786305714562)	1357.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1090.00	BARCODE-1786305714562-52	5	0.00
54	Test Product 53 (Batch 1786305714562)	1440.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	698.00	BARCODE-1786305714562-53	5	0.00
55	Test Product 54 (Batch 1786305714562)	2792.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1806.00	BARCODE-1786305714562-54	5	0.00
2	Test Product 1 (Batch 1786305714562)	2529.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-24 23:11:05.385096+02	2231.00	BARCODE-1786305714562-1	5	50.00
56	Test Product 55 (Batch 1786305714562)	2366.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2275.00	BARCODE-1786305714562-55	5	0.00
57	Test Product 56 (Batch 1786305714562)	1973.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1117.00	BARCODE-1786305714562-56	5	0.00
58	Test Product 57 (Batch 1786305714562)	1797.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1285.00	BARCODE-1786305714562-57	5	0.00
59	Test Product 58 (Batch 1786305714562)	1911.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1619.00	BARCODE-1786305714562-58	5	0.00
60	Test Product 59 (Batch 1786305714562)	1568.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	810.00	BARCODE-1786305714562-59	5	0.00
61	Test Product 60 (Batch 1786305714562)	1819.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1214.00	BARCODE-1786305714562-60	5	0.00
62	Test Product 61 (Batch 1786305714562)	1426.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	616.00	BARCODE-1786305714562-61	5	0.00
63	Test Product 62 (Batch 1786305714562)	1562.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1224.00	BARCODE-1786305714562-62	5	0.00
64	Test Product 63 (Batch 1786305714562)	831.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	515.00	BARCODE-1786305714562-63	5	0.00
65	Test Product 64 (Batch 1786305714562)	2434.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2429.00	BARCODE-1786305714562-64	5	0.00
66	Test Product 65 (Batch 1786305714562)	1492.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1297.00	BARCODE-1786305714562-65	5	0.00
67	Test Product 66 (Batch 1786305714562)	1841.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1609.00	BARCODE-1786305714562-66	5	0.00
68	Test Product 67 (Batch 1786305714562)	1212.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1190.00	BARCODE-1786305714562-67	5	0.00
69	Test Product 68 (Batch 1786305714562)	1979.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1112.00	BARCODE-1786305714562-68	5	0.00
70	Test Product 69 (Batch 1786305714562)	2383.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1741.00	BARCODE-1786305714562-69	5	0.00
71	Test Product 70 (Batch 1786305714562)	1395.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1292.00	BARCODE-1786305714562-70	5	0.00
72	Test Product 71 (Batch 1786305714562)	761.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	500.00	BARCODE-1786305714562-71	5	0.00
73	Test Product 72 (Batch 1786305714562)	2755.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2192.00	BARCODE-1786305714562-72	5	0.00
74	Test Product 73 (Batch 1786305714562)	1757.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1490.00	BARCODE-1786305714562-73	5	0.00
75	Test Product 74 (Batch 1786305714562)	2475.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1778.00	BARCODE-1786305714562-74	5	0.00
76	Test Product 75 (Batch 1786305714562)	1325.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1197.00	BARCODE-1786305714562-75	5	0.00
77	Test Product 76 (Batch 1786305714562)	2786.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2247.00	BARCODE-1786305714562-76	5	0.00
78	Test Product 77 (Batch 1786305714562)	2288.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1290.00	BARCODE-1786305714562-77	5	0.00
79	Test Product 78 (Batch 1786305714562)	2429.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2373.00	BARCODE-1786305714562-78	5	0.00
80	Test Product 79 (Batch 1786305714562)	2162.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1960.00	BARCODE-1786305714562-79	5	0.00
81	Test Product 80 (Batch 1786305714562)	2567.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2226.00	BARCODE-1786305714562-80	5	0.00
82	Test Product 81 (Batch 1786305714562)	2505.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1688.00	BARCODE-1786305714562-81	5	0.00
83	Test Product 82 (Batch 1786305714562)	1498.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	868.00	BARCODE-1786305714562-82	5	0.00
84	Test Product 83 (Batch 1786305714562)	2625.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2342.00	BARCODE-1786305714562-83	5	0.00
85	Test Product 84 (Batch 1786305714562)	2378.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2275.00	BARCODE-1786305714562-84	5	0.00
86	Test Product 85 (Batch 1786305714562)	2974.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2325.00	BARCODE-1786305714562-85	5	0.00
87	Test Product 86 (Batch 1786305714562)	2379.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2360.00	BARCODE-1786305714562-86	5	0.00
88	Test Product 87 (Batch 1786305714562)	1936.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1819.00	BARCODE-1786305714562-87	5	0.00
89	Test Product 88 (Batch 1786305714562)	1144.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	765.00	BARCODE-1786305714562-88	5	0.00
90	Test Product 89 (Batch 1786305714562)	1780.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1040.00	BARCODE-1786305714562-89	5	0.00
91	Test Product 90 (Batch 1786305714562)	2386.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1719.00	BARCODE-1786305714562-90	5	0.00
92	Test Product 91 (Batch 1786305714562)	2662.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1715.00	BARCODE-1786305714562-91	5	0.00
93	Test Product 92 (Batch 1786305714562)	1773.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1139.00	BARCODE-1786305714562-92	5	0.00
94	Test Product 93 (Batch 1786305714562)	1331.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	791.00	BARCODE-1786305714562-93	5	0.00
95	Test Product 94 (Batch 1786305714562)	2948.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2359.00	BARCODE-1786305714562-94	5	0.00
96	Test Product 95 (Batch 1786305714562)	1326.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	953.00	BARCODE-1786305714562-95	5	0.00
97	Test Product 96 (Batch 1786305714562)	3214.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2215.00	BARCODE-1786305714562-96	5	0.00
98	Test Product 97 (Batch 1786305714562)	1658.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1553.00	BARCODE-1786305714562-97	5	0.00
99	Test Product 98 (Batch 1786305714562)	2961.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2009.00	BARCODE-1786305714562-98	5	0.00
100	Test Product 99 (Batch 1786305714562)	1794.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1688.00	BARCODE-1786305714562-99	5	0.00
101	Test Product 100 (Batch 1786305714562)	2342.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1421.00	BARCODE-1786305714562-100	5	0.00
102	Test Product 101 (Batch 1786305714562)	750.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	663.00	BARCODE-1786305714562-101	5	0.00
103	Test Product 102 (Batch 1786305714562)	2559.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1778.00	BARCODE-1786305714562-102	5	0.00
104	Test Product 103 (Batch 1786305714562)	1162.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	584.00	BARCODE-1786305714562-103	5	0.00
105	Test Product 104 (Batch 1786305714562)	3087.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2279.00	BARCODE-1786305714562-104	5	0.00
106	Test Product 105 (Batch 1786305714562)	1834.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1328.00	BARCODE-1786305714562-105	5	0.00
107	Test Product 106 (Batch 1786305714562)	1685.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	702.00	BARCODE-1786305714562-106	5	0.00
108	Test Product 107 (Batch 1786305714562)	1179.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	852.00	BARCODE-1786305714562-107	5	0.00
109	Test Product 108 (Batch 1786305714562)	3045.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2280.00	BARCODE-1786305714562-108	5	0.00
110	Test Product 109 (Batch 1786305714562)	1969.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1366.00	BARCODE-1786305714562-109	5	0.00
111	Test Product 110 (Batch 1786305714562)	2187.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1823.00	BARCODE-1786305714562-110	5	0.00
112	Test Product 111 (Batch 1786305714562)	2469.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1754.00	BARCODE-1786305714562-111	5	0.00
113	Test Product 112 (Batch 1786305714562)	1990.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1365.00	BARCODE-1786305714562-112	5	0.00
114	Test Product 113 (Batch 1786305714562)	961.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	676.00	BARCODE-1786305714562-113	5	0.00
115	Test Product 114 (Batch 1786305714562)	636.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	504.00	BARCODE-1786305714562-114	5	0.00
116	Test Product 115 (Batch 1786305714562)	2257.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1362.00	BARCODE-1786305714562-115	5	0.00
117	Test Product 116 (Batch 1786305714562)	1611.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	866.00	BARCODE-1786305714562-116	5	0.00
118	Test Product 117 (Batch 1786305714562)	1579.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1010.00	BARCODE-1786305714562-117	5	0.00
119	Test Product 118 (Batch 1786305714562)	1577.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	803.00	BARCODE-1786305714562-118	5	0.00
120	Test Product 119 (Batch 1786305714562)	1458.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	613.00	BARCODE-1786305714562-119	5	0.00
121	Test Product 120 (Batch 1786305714562)	1306.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1046.00	BARCODE-1786305714562-120	5	0.00
122	Test Product 121 (Batch 1786305714562)	922.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	777.00	BARCODE-1786305714562-121	5	0.00
123	Test Product 122 (Batch 1786305714562)	1927.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	990.00	BARCODE-1786305714562-122	5	0.00
124	Test Product 123 (Batch 1786305714562)	1147.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	829.00	BARCODE-1786305714562-123	5	0.00
125	Test Product 124 (Batch 1786305714562)	1391.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	752.00	BARCODE-1786305714562-124	5	0.00
126	Test Product 125 (Batch 1786305714562)	1750.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	989.00	BARCODE-1786305714562-125	5	0.00
127	Test Product 126 (Batch 1786305714562)	2210.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1698.00	BARCODE-1786305714562-126	5	0.00
128	Test Product 127 (Batch 1786305714562)	2196.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1372.00	BARCODE-1786305714562-127	5	0.00
129	Test Product 128 (Batch 1786305714562)	1259.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1104.00	BARCODE-1786305714562-128	5	0.00
130	Test Product 129 (Batch 1786305714562)	2504.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2422.00	BARCODE-1786305714562-129	5	0.00
131	Test Product 130 (Batch 1786305714562)	1516.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1091.00	BARCODE-1786305714562-130	5	0.00
132	Test Product 131 (Batch 1786305714562)	772.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	752.00	BARCODE-1786305714562-131	5	0.00
133	Test Product 132 (Batch 1786305714562)	1880.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1446.00	BARCODE-1786305714562-132	5	0.00
134	Test Product 133 (Batch 1786305714562)	1639.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	828.00	BARCODE-1786305714562-133	5	0.00
135	Test Product 134 (Batch 1786305714562)	777.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	617.00	BARCODE-1786305714562-134	5	0.00
136	Test Product 135 (Batch 1786305714562)	2161.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2096.00	BARCODE-1786305714562-135	5	0.00
137	Test Product 136 (Batch 1786305714562)	2057.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1635.00	BARCODE-1786305714562-136	5	0.00
138	Test Product 137 (Batch 1786305714562)	2570.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1768.00	BARCODE-1786305714562-137	5	0.00
139	Test Product 138 (Batch 1786305714562)	1246.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	967.00	BARCODE-1786305714562-138	5	0.00
140	Test Product 139 (Batch 1786305714562)	2005.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1790.00	BARCODE-1786305714562-139	5	0.00
141	Test Product 140 (Batch 1786305714562)	2978.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1989.00	BARCODE-1786305714562-140	5	0.00
142	Test Product 141 (Batch 1786305714562)	2431.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1918.00	BARCODE-1786305714562-141	5	0.00
143	Test Product 142 (Batch 1786305714562)	2045.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1541.00	BARCODE-1786305714562-142	5	0.00
144	Test Product 143 (Batch 1786305714562)	2097.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1443.00	BARCODE-1786305714562-143	5	0.00
145	Test Product 144 (Batch 1786305714562)	1143.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	854.00	BARCODE-1786305714562-144	5	0.00
146	Test Product 145 (Batch 1786305714562)	1422.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1037.00	BARCODE-1786305714562-145	5	0.00
147	Test Product 146 (Batch 1786305714562)	1836.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1473.00	BARCODE-1786305714562-146	5	0.00
148	Test Product 147 (Batch 1786305714562)	3269.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2307.00	BARCODE-1786305714562-147	5	0.00
149	Test Product 148 (Batch 1786305714562)	2276.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2232.00	BARCODE-1786305714562-148	5	0.00
150	Test Product 149 (Batch 1786305714562)	2289.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1350.00	BARCODE-1786305714562-149	5	0.00
151	Test Product 150 (Batch 1786305714562)	924.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	507.00	BARCODE-1786305714562-150	5	0.00
152	Test Product 151 (Batch 1786305714562)	2424.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2054.00	BARCODE-1786305714562-151	5	0.00
153	Test Product 152 (Batch 1786305714562)	2644.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2055.00	BARCODE-1786305714562-152	5	0.00
154	Test Product 153 (Batch 1786305714562)	2612.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2292.00	BARCODE-1786305714562-153	5	0.00
155	Test Product 154 (Batch 1786305714562)	2858.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2285.00	BARCODE-1786305714562-154	5	0.00
156	Test Product 155 (Batch 1786305714562)	2765.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2471.00	BARCODE-1786305714562-155	5	0.00
157	Test Product 156 (Batch 1786305714562)	1793.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1785.00	BARCODE-1786305714562-156	5	0.00
158	Test Product 157 (Batch 1786305714562)	1405.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1026.00	BARCODE-1786305714562-157	5	0.00
159	Test Product 158 (Batch 1786305714562)	2493.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2439.00	BARCODE-1786305714562-158	5	0.00
160	Test Product 159 (Batch 1786305714562)	1405.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1186.00	BARCODE-1786305714562-159	5	0.00
161	Test Product 160 (Batch 1786305714562)	919.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	770.00	BARCODE-1786305714562-160	5	0.00
162	Test Product 161 (Batch 1786305714562)	2480.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1487.00	BARCODE-1786305714562-161	5	0.00
163	Test Product 162 (Batch 1786305714562)	2638.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1724.00	BARCODE-1786305714562-162	5	0.00
164	Test Product 163 (Batch 1786305714562)	2758.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2105.00	BARCODE-1786305714562-163	5	0.00
165	Test Product 164 (Batch 1786305714562)	2403.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2144.00	BARCODE-1786305714562-164	5	0.00
166	Test Product 165 (Batch 1786305714562)	2748.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1801.00	BARCODE-1786305714562-165	5	0.00
167	Test Product 166 (Batch 1786305714562)	1717.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	833.00	BARCODE-1786305714562-166	5	0.00
168	Test Product 167 (Batch 1786305714562)	538.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	518.00	BARCODE-1786305714562-167	5	0.00
169	Test Product 168 (Batch 1786305714562)	2168.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1524.00	BARCODE-1786305714562-168	5	0.00
170	Test Product 169 (Batch 1786305714562)	611.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	588.00	BARCODE-1786305714562-169	5	0.00
171	Test Product 170 (Batch 1786305714562)	2230.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1817.00	BARCODE-1786305714562-170	5	0.00
172	Test Product 171 (Batch 1786305714562)	2105.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2045.00	BARCODE-1786305714562-171	5	0.00
173	Test Product 172 (Batch 1786305714562)	1195.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	529.00	BARCODE-1786305714562-172	5	0.00
174	Test Product 173 (Batch 1786305714562)	1746.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1165.00	BARCODE-1786305714562-173	5	0.00
175	Test Product 174 (Batch 1786305714562)	1672.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1332.00	BARCODE-1786305714562-174	5	0.00
176	Test Product 175 (Batch 1786305714562)	1895.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1252.00	BARCODE-1786305714562-175	5	0.00
177	Test Product 176 (Batch 1786305714562)	2594.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2179.00	BARCODE-1786305714562-176	5	0.00
178	Test Product 177 (Batch 1786305714562)	1509.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	842.00	BARCODE-1786305714562-177	5	0.00
179	Test Product 178 (Batch 1786305714562)	1458.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1016.00	BARCODE-1786305714562-178	5	0.00
180	Test Product 179 (Batch 1786305714562)	1376.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1177.00	BARCODE-1786305714562-179	5	0.00
181	Test Product 180 (Batch 1786305714562)	2863.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2097.00	BARCODE-1786305714562-180	5	0.00
182	Test Product 181 (Batch 1786305714562)	1538.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1146.00	BARCODE-1786305714562-181	5	0.00
183	Test Product 182 (Batch 1786305714562)	2128.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1355.00	BARCODE-1786305714562-182	5	0.00
184	Test Product 183 (Batch 1786305714562)	1506.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	881.00	BARCODE-1786305714562-183	5	0.00
185	Test Product 184 (Batch 1786305714562)	1285.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1064.00	BARCODE-1786305714562-184	5	0.00
186	Test Product 185 (Batch 1786305714562)	1769.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1240.00	BARCODE-1786305714562-185	5	0.00
187	Test Product 186 (Batch 1786305714562)	1354.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	785.00	BARCODE-1786305714562-186	5	0.00
188	Test Product 187 (Batch 1786305714562)	2632.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2113.00	BARCODE-1786305714562-187	5	0.00
189	Test Product 188 (Batch 1786305714562)	1536.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1179.00	BARCODE-1786305714562-188	5	0.00
190	Test Product 189 (Batch 1786305714562)	1250.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1070.00	BARCODE-1786305714562-189	5	0.00
191	Test Product 190 (Batch 1786305714562)	1276.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	811.00	BARCODE-1786305714562-190	5	0.00
192	Test Product 191 (Batch 1786305714562)	1180.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	770.00	BARCODE-1786305714562-191	5	0.00
193	Test Product 192 (Batch 1786305714562)	2108.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1990.00	BARCODE-1786305714562-192	5	0.00
194	Test Product 193 (Batch 1786305714562)	2218.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1593.00	BARCODE-1786305714562-193	5	0.00
195	Test Product 194 (Batch 1786305714562)	2821.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2235.00	BARCODE-1786305714562-194	5	0.00
196	Test Product 195 (Batch 1786305714562)	2382.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2260.00	BARCODE-1786305714562-195	5	0.00
197	Test Product 196 (Batch 1786305714562)	2931.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2032.00	BARCODE-1786305714562-196	5	0.00
198	Test Product 197 (Batch 1786305714562)	1901.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1200.00	BARCODE-1786305714562-197	5	0.00
199	Test Product 198 (Batch 1786305714562)	2362.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1593.00	BARCODE-1786305714562-198	5	0.00
200	Test Product 199 (Batch 1786305714562)	2893.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2460.00	BARCODE-1786305714562-199	5	0.00
201	Test Product 200 (Batch 1786305714562)	1048.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	847.00	BARCODE-1786305714562-200	5	0.00
202	Test Product 201 (Batch 1786305714562)	3347.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2362.00	BARCODE-1786305714562-201	5	0.00
203	Test Product 202 (Batch 1786305714562)	2034.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1332.00	BARCODE-1786305714562-202	5	0.00
204	Test Product 203 (Batch 1786305714562)	1902.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1408.00	BARCODE-1786305714562-203	5	0.00
205	Test Product 204 (Batch 1786305714562)	1768.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1306.00	BARCODE-1786305714562-204	5	0.00
206	Test Product 205 (Batch 1786305714562)	1861.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	874.00	BARCODE-1786305714562-205	5	0.00
207	Test Product 206 (Batch 1786305714562)	1498.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1199.00	BARCODE-1786305714562-206	5	0.00
208	Test Product 207 (Batch 1786305714562)	1994.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1575.00	BARCODE-1786305714562-207	5	0.00
209	Test Product 208 (Batch 1786305714562)	1170.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	858.00	BARCODE-1786305714562-208	5	0.00
210	Test Product 209 (Batch 1786305714562)	3180.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2382.00	BARCODE-1786305714562-209	5	0.00
211	Test Product 210 (Batch 1786305714562)	1932.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1498.00	BARCODE-1786305714562-210	5	0.00
212	Test Product 211 (Batch 1786305714562)	2598.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2454.00	BARCODE-1786305714562-211	5	0.00
213	Test Product 212 (Batch 1786305714562)	1520.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1412.00	BARCODE-1786305714562-212	5	0.00
214	Test Product 213 (Batch 1786305714562)	1502.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	955.00	BARCODE-1786305714562-213	5	0.00
215	Test Product 214 (Batch 1786305714562)	2005.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1006.00	BARCODE-1786305714562-214	5	0.00
216	Test Product 215 (Batch 1786305714562)	1457.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	555.00	BARCODE-1786305714562-215	5	0.00
217	Test Product 216 (Batch 1786305714562)	1647.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	680.00	BARCODE-1786305714562-216	5	0.00
218	Test Product 217 (Batch 1786305714562)	1540.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1048.00	BARCODE-1786305714562-217	5	0.00
219	Test Product 218 (Batch 1786305714562)	2317.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1630.00	BARCODE-1786305714562-218	5	0.00
220	Test Product 219 (Batch 1786305714562)	3006.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2039.00	BARCODE-1786305714562-219	5	0.00
221	Test Product 220 (Batch 1786305714562)	1565.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1089.00	BARCODE-1786305714562-220	5	0.00
222	Test Product 221 (Batch 1786305714562)	1746.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	890.00	BARCODE-1786305714562-221	5	0.00
223	Test Product 222 (Batch 1786305714562)	1266.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	729.00	BARCODE-1786305714562-222	5	0.00
224	Test Product 223 (Batch 1786305714562)	2236.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2082.00	BARCODE-1786305714562-223	5	0.00
225	Test Product 224 (Batch 1786305714562)	1799.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1492.00	BARCODE-1786305714562-224	5	0.00
226	Test Product 225 (Batch 1786305714562)	2703.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2449.00	BARCODE-1786305714562-225	5	0.00
227	Test Product 226 (Batch 1786305714562)	3090.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2488.00	BARCODE-1786305714562-226	5	0.00
228	Test Product 227 (Batch 1786305714562)	997.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	799.00	BARCODE-1786305714562-227	5	0.00
229	Test Product 228 (Batch 1786305714562)	2440.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2200.00	BARCODE-1786305714562-228	5	0.00
230	Test Product 229 (Batch 1786305714562)	2903.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1987.00	BARCODE-1786305714562-229	5	0.00
231	Test Product 230 (Batch 1786305714562)	1285.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	838.00	BARCODE-1786305714562-230	5	0.00
232	Test Product 231 (Batch 1786305714562)	2490.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2482.00	BARCODE-1786305714562-231	5	0.00
233	Test Product 232 (Batch 1786305714562)	1183.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	715.00	BARCODE-1786305714562-232	5	0.00
234	Test Product 233 (Batch 1786305714562)	985.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	536.00	BARCODE-1786305714562-233	5	0.00
235	Test Product 234 (Batch 1786305714562)	2936.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2181.00	BARCODE-1786305714562-234	5	0.00
236	Test Product 235 (Batch 1786305714562)	2928.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2244.00	BARCODE-1786305714562-235	5	0.00
237	Test Product 236 (Batch 1786305714562)	2594.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2250.00	BARCODE-1786305714562-236	5	0.00
238	Test Product 237 (Batch 1786305714562)	1254.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	883.00	BARCODE-1786305714562-237	5	0.00
239	Test Product 238 (Batch 1786305714562)	1496.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	852.00	BARCODE-1786305714562-238	5	0.00
240	Test Product 239 (Batch 1786305714562)	1403.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	788.00	BARCODE-1786305714562-239	5	0.00
241	Test Product 240 (Batch 1786305714562)	1078.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	532.00	BARCODE-1786305714562-240	5	0.00
242	Test Product 241 (Batch 1786305714562)	1878.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1434.00	BARCODE-1786305714562-241	5	0.00
243	Test Product 242 (Batch 1786305714562)	2400.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2195.00	BARCODE-1786305714562-242	5	0.00
244	Test Product 243 (Batch 1786305714562)	2726.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2206.00	BARCODE-1786305714562-243	5	0.00
245	Test Product 244 (Batch 1786305714562)	1139.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	662.00	BARCODE-1786305714562-244	5	0.00
246	Test Product 245 (Batch 1786305714562)	2061.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1768.00	BARCODE-1786305714562-245	5	0.00
247	Test Product 246 (Batch 1786305714562)	1676.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1563.00	BARCODE-1786305714562-246	5	0.00
248	Test Product 247 (Batch 1786305714562)	2360.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1560.00	BARCODE-1786305714562-247	5	0.00
249	Test Product 248 (Batch 1786305714562)	2655.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2282.00	BARCODE-1786305714562-248	5	0.00
250	Test Product 249 (Batch 1786305714562)	2194.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1720.00	BARCODE-1786305714562-249	5	0.00
251	Test Product 250 (Batch 1786305714562)	1018.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	549.00	BARCODE-1786305714562-250	5	0.00
252	Test Product 251 (Batch 1786305714562)	2183.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2092.00	BARCODE-1786305714562-251	5	0.00
253	Test Product 252 (Batch 1786305714562)	831.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	788.00	BARCODE-1786305714562-252	5	0.00
254	Test Product 253 (Batch 1786305714562)	2488.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2279.00	BARCODE-1786305714562-253	5	0.00
255	Test Product 254 (Batch 1786305714562)	1683.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1151.00	BARCODE-1786305714562-254	5	0.00
256	Test Product 255 (Batch 1786305714562)	1959.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1898.00	BARCODE-1786305714562-255	5	0.00
257	Test Product 256 (Batch 1786305714562)	809.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	681.00	BARCODE-1786305714562-256	5	0.00
258	Test Product 257 (Batch 1786305714562)	2644.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2267.00	BARCODE-1786305714562-257	5	0.00
259	Test Product 258 (Batch 1786305714562)	2374.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2294.00	BARCODE-1786305714562-258	5	0.00
260	Test Product 259 (Batch 1786305714562)	2134.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1166.00	BARCODE-1786305714562-259	5	0.00
261	Test Product 260 (Batch 1786305714562)	1380.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1032.00	BARCODE-1786305714562-260	5	0.00
262	Test Product 261 (Batch 1786305714562)	2806.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2042.00	BARCODE-1786305714562-261	5	0.00
263	Test Product 262 (Batch 1786305714562)	2518.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2328.00	BARCODE-1786305714562-262	5	0.00
264	Test Product 263 (Batch 1786305714562)	2280.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1317.00	BARCODE-1786305714562-263	5	0.00
265	Test Product 264 (Batch 1786305714562)	1317.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	749.00	BARCODE-1786305714562-264	5	0.00
266	Test Product 265 (Batch 1786305714562)	1149.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	706.00	BARCODE-1786305714562-265	5	0.00
267	Test Product 266 (Batch 1786305714562)	1530.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	840.00	BARCODE-1786305714562-266	5	0.00
268	Test Product 267 (Batch 1786305714562)	818.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	578.00	BARCODE-1786305714562-267	5	0.00
269	Test Product 268 (Batch 1786305714562)	1379.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	990.00	BARCODE-1786305714562-268	5	0.00
270	Test Product 269 (Batch 1786305714562)	1898.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1544.00	BARCODE-1786305714562-269	5	0.00
271	Test Product 270 (Batch 1786305714562)	759.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	655.00	BARCODE-1786305714562-270	5	0.00
272	Test Product 271 (Batch 1786305714562)	2696.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1867.00	BARCODE-1786305714562-271	5	0.00
273	Test Product 272 (Batch 1786305714562)	1415.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	658.00	BARCODE-1786305714562-272	5	0.00
274	Test Product 273 (Batch 1786305714562)	2444.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1586.00	BARCODE-1786305714562-273	5	0.00
275	Test Product 274 (Batch 1786305714562)	2348.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1766.00	BARCODE-1786305714562-274	5	0.00
276	Test Product 275 (Batch 1786305714562)	2392.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2354.00	BARCODE-1786305714562-275	5	0.00
277	Test Product 276 (Batch 1786305714562)	1417.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1043.00	BARCODE-1786305714562-276	5	0.00
278	Test Product 277 (Batch 1786305714562)	2580.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2198.00	BARCODE-1786305714562-277	5	0.00
279	Test Product 278 (Batch 1786305714562)	2536.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2476.00	BARCODE-1786305714562-278	5	0.00
280	Test Product 279 (Batch 1786305714562)	1473.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1372.00	BARCODE-1786305714562-279	5	0.00
281	Test Product 280 (Batch 1786305714562)	1779.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1431.00	BARCODE-1786305714562-280	5	0.00
282	Test Product 281 (Batch 1786305714562)	1214.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	818.00	BARCODE-1786305714562-281	5	0.00
283	Test Product 282 (Batch 1786305714562)	2560.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2223.00	BARCODE-1786305714562-282	5	0.00
284	Test Product 283 (Batch 1786305714562)	2549.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2494.00	BARCODE-1786305714562-283	5	0.00
285	Test Product 284 (Batch 1786305714562)	2251.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1675.00	BARCODE-1786305714562-284	5	0.00
286	Test Product 285 (Batch 1786305714562)	1603.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1026.00	BARCODE-1786305714562-285	5	0.00
287	Test Product 286 (Batch 1786305714562)	878.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	539.00	BARCODE-1786305714562-286	5	0.00
288	Test Product 287 (Batch 1786305714562)	1009.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	699.00	BARCODE-1786305714562-287	5	0.00
289	Test Product 288 (Batch 1786305714562)	2753.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1890.00	BARCODE-1786305714562-288	5	0.00
290	Test Product 289 (Batch 1786305714562)	983.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	949.00	BARCODE-1786305714562-289	5	0.00
291	Test Product 290 (Batch 1786305714562)	992.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	687.00	BARCODE-1786305714562-290	5	0.00
292	Test Product 291 (Batch 1786305714562)	1548.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1405.00	BARCODE-1786305714562-291	5	0.00
293	Test Product 292 (Batch 1786305714562)	2665.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1684.00	BARCODE-1786305714562-292	5	0.00
294	Test Product 293 (Batch 1786305714562)	1943.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1761.00	BARCODE-1786305714562-293	5	0.00
295	Test Product 294 (Batch 1786305714562)	2380.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1740.00	BARCODE-1786305714562-294	5	0.00
296	Test Product 295 (Batch 1786305714562)	2222.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1576.00	BARCODE-1786305714562-295	5	0.00
297	Test Product 296 (Batch 1786305714562)	2193.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2187.00	BARCODE-1786305714562-296	5	0.00
298	Test Product 297 (Batch 1786305714562)	3056.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2136.00	BARCODE-1786305714562-297	5	0.00
299	Test Product 298 (Batch 1786305714562)	1129.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	832.00	BARCODE-1786305714562-298	5	0.00
300	Test Product 299 (Batch 1786305714562)	2587.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1792.00	BARCODE-1786305714562-299	5	0.00
301	Test Product 300 (Batch 1786305714562)	1677.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1422.00	BARCODE-1786305714562-300	5	0.00
302	Test Product 301 (Batch 1786305714562)	2550.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1596.00	BARCODE-1786305714562-301	5	0.00
303	Test Product 302 (Batch 1786305714562)	1990.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1389.00	BARCODE-1786305714562-302	5	0.00
304	Test Product 303 (Batch 1786305714562)	1770.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1267.00	BARCODE-1786305714562-303	5	0.00
305	Test Product 304 (Batch 1786305714562)	2466.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2380.00	BARCODE-1786305714562-304	5	0.00
306	Test Product 305 (Batch 1786305714562)	3010.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2106.00	BARCODE-1786305714562-305	5	0.00
307	Test Product 306 (Batch 1786305714562)	1869.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	940.00	BARCODE-1786305714562-306	5	0.00
308	Test Product 307 (Batch 1786305714562)	2154.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2044.00	BARCODE-1786305714562-307	5	0.00
309	Test Product 308 (Batch 1786305714562)	1393.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	747.00	BARCODE-1786305714562-308	5	0.00
310	Test Product 309 (Batch 1786305714562)	2006.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1765.00	BARCODE-1786305714562-309	5	0.00
311	Test Product 310 (Batch 1786305714562)	1341.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	531.00	BARCODE-1786305714562-310	5	0.00
312	Test Product 311 (Batch 1786305714562)	1956.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	964.00	BARCODE-1786305714562-311	5	0.00
313	Test Product 312 (Batch 1786305714562)	1083.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	569.00	BARCODE-1786305714562-312	5	0.00
314	Test Product 313 (Batch 1786305714562)	1977.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1090.00	BARCODE-1786305714562-313	5	0.00
315	Test Product 314 (Batch 1786305714562)	2220.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1229.00	BARCODE-1786305714562-314	5	0.00
316	Test Product 315 (Batch 1786305714562)	1967.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1959.00	BARCODE-1786305714562-315	5	0.00
317	Test Product 316 (Batch 1786305714562)	2729.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2060.00	BARCODE-1786305714562-316	5	0.00
318	Test Product 317 (Batch 1786305714562)	1882.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1482.00	BARCODE-1786305714562-317	5	0.00
319	Test Product 318 (Batch 1786305714562)	2276.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2188.00	BARCODE-1786305714562-318	5	0.00
320	Test Product 319 (Batch 1786305714562)	1559.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1082.00	BARCODE-1786305714562-319	5	0.00
321	Test Product 320 (Batch 1786305714562)	1514.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1172.00	BARCODE-1786305714562-320	5	0.00
322	Test Product 321 (Batch 1786305714562)	2353.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1565.00	BARCODE-1786305714562-321	5	0.00
323	Test Product 322 (Batch 1786305714562)	1108.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	937.00	BARCODE-1786305714562-322	5	0.00
324	Test Product 323 (Batch 1786305714562)	1386.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	951.00	BARCODE-1786305714562-323	5	0.00
325	Test Product 324 (Batch 1786305714562)	1484.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	896.00	BARCODE-1786305714562-324	5	0.00
326	Test Product 325 (Batch 1786305714562)	1854.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	945.00	BARCODE-1786305714562-325	5	0.00
327	Test Product 326 (Batch 1786305714562)	1632.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1581.00	BARCODE-1786305714562-326	5	0.00
328	Test Product 327 (Batch 1786305714562)	2460.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1959.00	BARCODE-1786305714562-327	5	0.00
329	Test Product 328 (Batch 1786305714562)	2265.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1580.00	BARCODE-1786305714562-328	5	0.00
330	Test Product 329 (Batch 1786305714562)	2938.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2093.00	BARCODE-1786305714562-329	5	0.00
331	Test Product 330 (Batch 1786305714562)	1457.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	844.00	BARCODE-1786305714562-330	5	0.00
332	Test Product 331 (Batch 1786305714562)	1728.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1387.00	BARCODE-1786305714562-331	5	0.00
333	Test Product 332 (Batch 1786305714562)	1150.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	998.00	BARCODE-1786305714562-332	5	0.00
334	Test Product 333 (Batch 1786305714562)	2636.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2378.00	BARCODE-1786305714562-333	5	0.00
335	Test Product 334 (Batch 1786305714562)	2138.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1442.00	BARCODE-1786305714562-334	5	0.00
336	Test Product 335 (Batch 1786305714562)	1419.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1097.00	BARCODE-1786305714562-335	5	0.00
337	Test Product 336 (Batch 1786305714562)	2043.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1219.00	BARCODE-1786305714562-336	5	0.00
338	Test Product 337 (Batch 1786305714562)	1640.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1133.00	BARCODE-1786305714562-337	5	0.00
339	Test Product 338 (Batch 1786305714562)	715.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	686.00	BARCODE-1786305714562-338	5	0.00
340	Test Product 339 (Batch 1786305714562)	2016.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1948.00	BARCODE-1786305714562-339	5	0.00
341	Test Product 340 (Batch 1786305714562)	3008.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2135.00	BARCODE-1786305714562-340	5	0.00
342	Test Product 341 (Batch 1786305714562)	1640.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	810.00	BARCODE-1786305714562-341	5	0.00
343	Test Product 342 (Batch 1786305714562)	2438.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1747.00	BARCODE-1786305714562-342	5	0.00
344	Test Product 343 (Batch 1786305714562)	2351.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1698.00	BARCODE-1786305714562-343	5	0.00
345	Test Product 344 (Batch 1786305714562)	2380.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1987.00	BARCODE-1786305714562-344	5	0.00
346	Test Product 345 (Batch 1786305714562)	1881.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1401.00	BARCODE-1786305714562-345	5	0.00
347	Test Product 346 (Batch 1786305714562)	1842.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	948.00	BARCODE-1786305714562-346	5	0.00
348	Test Product 347 (Batch 1786305714562)	1510.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1138.00	BARCODE-1786305714562-347	5	0.00
349	Test Product 348 (Batch 1786305714562)	844.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	771.00	BARCODE-1786305714562-348	5	0.00
350	Test Product 349 (Batch 1786305714562)	2261.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1632.00	BARCODE-1786305714562-349	5	0.00
351	Test Product 350 (Batch 1786305714562)	2834.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2106.00	BARCODE-1786305714562-350	5	0.00
352	Test Product 351 (Batch 1786305714562)	1659.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1164.00	BARCODE-1786305714562-351	5	0.00
353	Test Product 352 (Batch 1786305714562)	673.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	502.00	BARCODE-1786305714562-352	5	0.00
354	Test Product 353 (Batch 1786305714562)	2125.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1550.00	BARCODE-1786305714562-353	5	0.00
355	Test Product 354 (Batch 1786305714562)	1812.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1714.00	BARCODE-1786305714562-354	5	0.00
356	Test Product 355 (Batch 1786305714562)	951.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	779.00	BARCODE-1786305714562-355	5	0.00
357	Test Product 356 (Batch 1786305714562)	1201.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	539.00	BARCODE-1786305714562-356	5	0.00
358	Test Product 357 (Batch 1786305714562)	2054.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1277.00	BARCODE-1786305714562-357	5	0.00
359	Test Product 358 (Batch 1786305714562)	2586.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2293.00	BARCODE-1786305714562-358	5	0.00
360	Test Product 359 (Batch 1786305714562)	747.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	511.00	BARCODE-1786305714562-359	5	0.00
361	Test Product 360 (Batch 1786305714562)	1824.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1330.00	BARCODE-1786305714562-360	5	0.00
362	Test Product 361 (Batch 1786305714562)	2334.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2106.00	BARCODE-1786305714562-361	5	0.00
363	Test Product 362 (Batch 1786305714562)	1501.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	546.00	BARCODE-1786305714562-362	5	0.00
364	Test Product 363 (Batch 1786305714562)	1721.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	736.00	BARCODE-1786305714562-363	5	0.00
365	Test Product 364 (Batch 1786305714562)	2476.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2363.00	BARCODE-1786305714562-364	5	0.00
366	Test Product 365 (Batch 1786305714562)	2477.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1811.00	BARCODE-1786305714562-365	5	0.00
367	Test Product 366 (Batch 1786305714562)	1447.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1024.00	BARCODE-1786305714562-366	5	0.00
368	Test Product 367 (Batch 1786305714562)	2160.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2092.00	BARCODE-1786305714562-367	5	0.00
369	Test Product 368 (Batch 1786305714562)	2363.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1491.00	BARCODE-1786305714562-368	5	0.00
370	Test Product 369 (Batch 1786305714562)	1076.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1058.00	BARCODE-1786305714562-369	5	0.00
371	Test Product 370 (Batch 1786305714562)	2580.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2297.00	BARCODE-1786305714562-370	5	0.00
372	Test Product 371 (Batch 1786305714562)	986.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	614.00	BARCODE-1786305714562-371	5	0.00
373	Test Product 372 (Batch 1786305714562)	1135.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	867.00	BARCODE-1786305714562-372	5	0.00
374	Test Product 373 (Batch 1786305714562)	1487.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1148.00	BARCODE-1786305714562-373	5	0.00
375	Test Product 374 (Batch 1786305714562)	2472.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2099.00	BARCODE-1786305714562-374	5	0.00
376	Test Product 375 (Batch 1786305714562)	1388.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1100.00	BARCODE-1786305714562-375	5	0.00
377	Test Product 376 (Batch 1786305714562)	1326.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	576.00	BARCODE-1786305714562-376	5	0.00
378	Test Product 377 (Batch 1786305714562)	1843.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1324.00	BARCODE-1786305714562-377	5	0.00
379	Test Product 378 (Batch 1786305714562)	1300.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	615.00	BARCODE-1786305714562-378	5	0.00
380	Test Product 379 (Batch 1786305714562)	2049.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1271.00	BARCODE-1786305714562-379	5	0.00
381	Test Product 380 (Batch 1786305714562)	2663.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2361.00	BARCODE-1786305714562-380	5	0.00
382	Test Product 381 (Batch 1786305714562)	1573.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	998.00	BARCODE-1786305714562-381	5	0.00
383	Test Product 382 (Batch 1786305714562)	2279.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1883.00	BARCODE-1786305714562-382	5	0.00
384	Test Product 383 (Batch 1786305714562)	2264.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1517.00	BARCODE-1786305714562-383	5	0.00
385	Test Product 384 (Batch 1786305714562)	2338.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1466.00	BARCODE-1786305714562-384	5	0.00
386	Test Product 385 (Batch 1786305714562)	2137.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1523.00	BARCODE-1786305714562-385	5	0.00
387	Test Product 386 (Batch 1786305714562)	2676.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2148.00	BARCODE-1786305714562-386	5	0.00
388	Test Product 387 (Batch 1786305714562)	2593.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2044.00	BARCODE-1786305714562-387	5	0.00
389	Test Product 388 (Batch 1786305714562)	1531.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	569.00	BARCODE-1786305714562-388	5	0.00
390	Test Product 389 (Batch 1786305714562)	2897.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2130.00	BARCODE-1786305714562-389	5	0.00
391	Test Product 390 (Batch 1786305714562)	2325.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2078.00	BARCODE-1786305714562-390	5	0.00
392	Test Product 391 (Batch 1786305714562)	1096.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	836.00	BARCODE-1786305714562-391	5	0.00
393	Test Product 392 (Batch 1786305714562)	2939.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2007.00	BARCODE-1786305714562-392	5	0.00
394	Test Product 393 (Batch 1786305714562)	2075.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1966.00	BARCODE-1786305714562-393	5	0.00
395	Test Product 394 (Batch 1786305714562)	2177.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2071.00	BARCODE-1786305714562-394	5	0.00
396	Test Product 395 (Batch 1786305714562)	2248.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1614.00	BARCODE-1786305714562-395	5	0.00
397	Test Product 396 (Batch 1786305714562)	2490.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1687.00	BARCODE-1786305714562-396	5	0.00
398	Test Product 397 (Batch 1786305714562)	1726.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1399.00	BARCODE-1786305714562-397	5	0.00
399	Test Product 398 (Batch 1786305714562)	2741.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1839.00	BARCODE-1786305714562-398	5	0.00
400	Test Product 399 (Batch 1786305714562)	1745.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1288.00	BARCODE-1786305714562-399	5	0.00
401	Test Product 400 (Batch 1786305714562)	1903.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1484.00	BARCODE-1786305714562-400	5	0.00
402	Test Product 401 (Batch 1786305714562)	2235.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2122.00	BARCODE-1786305714562-401	5	0.00
403	Test Product 402 (Batch 1786305714562)	2396.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1691.00	BARCODE-1786305714562-402	5	0.00
404	Test Product 403 (Batch 1786305714562)	2138.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1308.00	BARCODE-1786305714562-403	5	0.00
405	Test Product 404 (Batch 1786305714562)	1070.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1024.00	BARCODE-1786305714562-404	5	0.00
406	Test Product 405 (Batch 1786305714562)	1081.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	588.00	BARCODE-1786305714562-405	5	0.00
407	Test Product 406 (Batch 1786305714562)	2152.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1200.00	BARCODE-1786305714562-406	5	0.00
408	Test Product 407 (Batch 1786305714562)	1752.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1267.00	BARCODE-1786305714562-407	5	0.00
409	Test Product 408 (Batch 1786305714562)	2354.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1571.00	BARCODE-1786305714562-408	5	0.00
410	Test Product 409 (Batch 1786305714562)	2019.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1764.00	BARCODE-1786305714562-409	5	0.00
411	Test Product 410 (Batch 1786305714562)	1342.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	650.00	BARCODE-1786305714562-410	5	0.00
412	Test Product 411 (Batch 1786305714562)	1456.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1249.00	BARCODE-1786305714562-411	5	0.00
413	Test Product 412 (Batch 1786305714562)	2452.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2208.00	BARCODE-1786305714562-412	5	0.00
414	Test Product 413 (Batch 1786305714562)	1556.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	678.00	BARCODE-1786305714562-413	5	0.00
415	Test Product 414 (Batch 1786305714562)	1074.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	684.00	BARCODE-1786305714562-414	5	0.00
416	Test Product 415 (Batch 1786305714562)	2066.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1202.00	BARCODE-1786305714562-415	5	0.00
417	Test Product 416 (Batch 1786305714562)	1932.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1027.00	BARCODE-1786305714562-416	5	0.00
418	Test Product 417 (Batch 1786305714562)	2633.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2083.00	BARCODE-1786305714562-417	5	0.00
419	Test Product 418 (Batch 1786305714562)	2669.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2348.00	BARCODE-1786305714562-418	5	0.00
420	Test Product 419 (Batch 1786305714562)	2620.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2074.00	BARCODE-1786305714562-419	5	0.00
421	Test Product 420 (Batch 1786305714562)	2232.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2145.00	BARCODE-1786305714562-420	5	0.00
422	Test Product 421 (Batch 1786305714562)	1104.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1055.00	BARCODE-1786305714562-421	5	0.00
423	Test Product 422 (Batch 1786305714562)	2988.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2055.00	BARCODE-1786305714562-422	5	0.00
424	Test Product 423 (Batch 1786305714562)	1935.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1814.00	BARCODE-1786305714562-423	5	0.00
425	Test Product 424 (Batch 1786305714562)	1681.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1162.00	BARCODE-1786305714562-424	5	0.00
426	Test Product 425 (Batch 1786305714562)	1969.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1664.00	BARCODE-1786305714562-425	5	0.00
427	Test Product 426 (Batch 1786305714562)	1148.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	872.00	BARCODE-1786305714562-426	5	0.00
428	Test Product 427 (Batch 1786305714562)	1504.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1243.00	BARCODE-1786305714562-427	5	0.00
429	Test Product 428 (Batch 1786305714562)	581.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	517.00	BARCODE-1786305714562-428	5	0.00
430	Test Product 429 (Batch 1786305714562)	2649.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1966.00	BARCODE-1786305714562-429	5	0.00
431	Test Product 430 (Batch 1786305714562)	2258.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1628.00	BARCODE-1786305714562-430	5	0.00
432	Test Product 431 (Batch 1786305714562)	831.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	558.00	BARCODE-1786305714562-431	5	0.00
433	Test Product 432 (Batch 1786305714562)	771.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	771.00	BARCODE-1786305714562-432	5	0.00
434	Test Product 433 (Batch 1786305714562)	3445.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2467.00	BARCODE-1786305714562-433	5	0.00
435	Test Product 434 (Batch 1786305714562)	2684.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1952.00	BARCODE-1786305714562-434	5	0.00
436	Test Product 435 (Batch 1786305714562)	645.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	520.00	BARCODE-1786305714562-435	5	0.00
437	Test Product 436 (Batch 1786305714562)	1488.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1468.00	BARCODE-1786305714562-436	5	0.00
438	Test Product 437 (Batch 1786305714562)	785.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	633.00	BARCODE-1786305714562-437	5	0.00
439	Test Product 438 (Batch 1786305714562)	2617.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2207.00	BARCODE-1786305714562-438	5	0.00
440	Test Product 439 (Batch 1786305714562)	2357.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1649.00	BARCODE-1786305714562-439	5	0.00
441	Test Product 440 (Batch 1786305714562)	3249.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2400.00	BARCODE-1786305714562-440	5	0.00
442	Test Product 441 (Batch 1786305714562)	1756.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1539.00	BARCODE-1786305714562-441	5	0.00
443	Test Product 442 (Batch 1786305714562)	1372.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	798.00	BARCODE-1786305714562-442	5	0.00
444	Test Product 443 (Batch 1786305714562)	2098.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1734.00	BARCODE-1786305714562-443	5	0.00
445	Test Product 444 (Batch 1786305714562)	1484.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1301.00	BARCODE-1786305714562-444	5	0.00
446	Test Product 445 (Batch 1786305714562)	1783.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1291.00	BARCODE-1786305714562-445	5	0.00
447	Test Product 446 (Batch 1786305714562)	1746.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1622.00	BARCODE-1786305714562-446	5	0.00
448	Test Product 447 (Batch 1786305714562)	1926.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1909.00	BARCODE-1786305714562-447	5	0.00
449	Test Product 448 (Batch 1786305714562)	891.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	840.00	BARCODE-1786305714562-448	5	0.00
450	Test Product 449 (Batch 1786305714562)	2348.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1996.00	BARCODE-1786305714562-449	5	0.00
451	Test Product 450 (Batch 1786305714562)	1814.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1722.00	BARCODE-1786305714562-450	5	0.00
452	Test Product 451 (Batch 1786305714562)	1802.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	925.00	BARCODE-1786305714562-451	5	0.00
453	Test Product 452 (Batch 1786305714562)	1903.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1555.00	BARCODE-1786305714562-452	5	0.00
454	Test Product 453 (Batch 1786305714562)	2122.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1618.00	BARCODE-1786305714562-453	5	0.00
455	Test Product 454 (Batch 1786305714562)	2127.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1135.00	BARCODE-1786305714562-454	5	0.00
456	Test Product 455 (Batch 1786305714562)	2629.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2171.00	BARCODE-1786305714562-455	5	0.00
457	Test Product 456 (Batch 1786305714562)	2838.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2151.00	BARCODE-1786305714562-456	5	0.00
458	Test Product 457 (Batch 1786305714562)	1359.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	952.00	BARCODE-1786305714562-457	5	0.00
459	Test Product 458 (Batch 1786305714562)	2485.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1529.00	BARCODE-1786305714562-458	5	0.00
460	Test Product 459 (Batch 1786305714562)	1205.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1136.00	BARCODE-1786305714562-459	5	0.00
461	Test Product 460 (Batch 1786305714562)	1829.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1619.00	BARCODE-1786305714562-460	5	0.00
462	Test Product 461 (Batch 1786305714562)	1505.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	817.00	BARCODE-1786305714562-461	5	0.00
463	Test Product 462 (Batch 1786305714562)	2828.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1885.00	BARCODE-1786305714562-462	5	0.00
464	Test Product 463 (Batch 1786305714562)	2402.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1585.00	BARCODE-1786305714562-463	5	0.00
465	Test Product 464 (Batch 1786305714562)	2586.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2119.00	BARCODE-1786305714562-464	5	0.00
466	Test Product 465 (Batch 1786305714562)	2437.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2197.00	BARCODE-1786305714562-465	5	0.00
467	Test Product 466 (Batch 1786305714562)	1111.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	542.00	BARCODE-1786305714562-466	5	0.00
468	Test Product 467 (Batch 1786305714562)	1363.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	762.00	BARCODE-1786305714562-467	5	0.00
469	Test Product 468 (Batch 1786305714562)	2059.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1975.00	BARCODE-1786305714562-468	5	0.00
470	Test Product 469 (Batch 1786305714562)	1588.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	646.00	BARCODE-1786305714562-469	5	0.00
471	Test Product 470 (Batch 1786305714562)	1752.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1456.00	BARCODE-1786305714562-470	5	0.00
472	Test Product 471 (Batch 1786305714562)	2735.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2015.00	BARCODE-1786305714562-471	5	0.00
473	Test Product 472 (Batch 1786305714562)	1899.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1006.00	BARCODE-1786305714562-472	5	0.00
474	Test Product 473 (Batch 1786305714562)	2050.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2029.00	BARCODE-1786305714562-473	5	0.00
475	Test Product 474 (Batch 1786305714562)	1568.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1003.00	BARCODE-1786305714562-474	5	0.00
476	Test Product 475 (Batch 1786305714562)	803.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	656.00	BARCODE-1786305714562-475	5	0.00
477	Test Product 476 (Batch 1786305714562)	2456.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1985.00	BARCODE-1786305714562-476	5	0.00
478	Test Product 477 (Batch 1786305714562)	2747.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2271.00	BARCODE-1786305714562-477	5	0.00
479	Test Product 478 (Batch 1786305714562)	1510.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	953.00	BARCODE-1786305714562-478	5	0.00
480	Test Product 479 (Batch 1786305714562)	2106.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1647.00	BARCODE-1786305714562-479	5	0.00
481	Test Product 480 (Batch 1786305714562)	2883.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1892.00	BARCODE-1786305714562-480	5	0.00
482	Test Product 481 (Batch 1786305714562)	2757.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2432.00	BARCODE-1786305714562-481	5	0.00
483	Test Product 482 (Batch 1786305714562)	2701.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1952.00	BARCODE-1786305714562-482	5	0.00
484	Test Product 483 (Batch 1786305714562)	2970.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2224.00	BARCODE-1786305714562-483	5	0.00
485	Test Product 484 (Batch 1786305714562)	2969.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2274.00	BARCODE-1786305714562-484	5	0.00
486	Test Product 485 (Batch 1786305714562)	1435.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1197.00	BARCODE-1786305714562-485	5	0.00
487	Test Product 486 (Batch 1786305714562)	2363.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1941.00	BARCODE-1786305714562-486	5	0.00
488	Test Product 487 (Batch 1786305714562)	1843.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1280.00	BARCODE-1786305714562-487	5	0.00
489	Test Product 488 (Batch 1786305714562)	1547.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	882.00	BARCODE-1786305714562-488	5	0.00
490	Test Product 489 (Batch 1786305714562)	2902.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2260.00	BARCODE-1786305714562-489	5	0.00
491	Test Product 490 (Batch 1786305714562)	1311.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	682.00	BARCODE-1786305714562-490	5	0.00
492	Test Product 491 (Batch 1786305714562)	2871.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1933.00	BARCODE-1786305714562-491	5	0.00
493	Test Product 492 (Batch 1786305714562)	1732.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1562.00	BARCODE-1786305714562-492	5	0.00
494	Test Product 493 (Batch 1786305714562)	1752.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	994.00	BARCODE-1786305714562-493	5	0.00
495	Test Product 494 (Batch 1786305714562)	1388.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1007.00	BARCODE-1786305714562-494	5	0.00
496	Test Product 495 (Batch 1786305714562)	1048.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	634.00	BARCODE-1786305714562-495	5	0.00
497	Test Product 496 (Batch 1786305714562)	1226.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	902.00	BARCODE-1786305714562-496	5	0.00
498	Test Product 497 (Batch 1786305714562)	3167.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	2256.00	BARCODE-1786305714562-497	5	0.00
499	Test Product 498 (Batch 1786305714562)	2189.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1956.00	BARCODE-1786305714562-498	5	0.00
500	Test Product 499 (Batch 1786305714562)	2392.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1506.00	BARCODE-1786305714562-499	5	0.00
501	Test Product 500 (Batch 1786305714562)	1893.00	1	50.00	t	0	2026-08-09 22:01:54.557407+02	2026-08-09 22:01:54.557407+02	1578.00	BARCODE-1786305714562-500	5	0.00
1	Samsung Galaxy A56 5G 8/128	55000.00	6	100.00	t	0	2026-08-09 21:59:46.694492+02	2026-08-24 22:47:05.332645+02	53000.00	125060	5	100.00
\.


--
-- TOC entry 5420 (class 0 OID 16868)
-- Dependencies: 226
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.refresh_tokens (id, user_id, token_hash, issued_at, expires_at, is_revoked, revoked_at, ip_address) FROM stdin;
190	1	5291d4e89246b907c4979f2a5155ca7894b1bbdeea1eed2117522a479accfc67	2026-08-26 21:05:03.021928+02	2026-08-27 05:05:03.021+02	t	2026-08-27 18:16:44.23273+02	\N
196	2	00b734d6222fffa188dadf0a66e225d52bb38000a75de9381617c0370941082a	2026-08-27 00:21:38.551949+02	2026-08-27 08:21:38.551+02	t	2026-08-27 02:01:50.664315+02	\N
180	2	99f3be4cfb9257f33891169c715f5ee85331fc2f4cdb39dbe5391c4da31bb73a	2026-08-26 16:28:23.886525+02	2026-08-27 00:28:23.884+02	t	2026-08-27 02:01:50.664315+02	\N
167	2	628f0f043528fd6f20dda93d42083f30fde50e46447200115d75c0ff6be3403d	2026-08-25 20:21:56.113131+02	2026-08-26 04:21:56.112+02	t	2026-08-27 02:01:50.664315+02	\N
162	2	970ceabccf8dc60136ec2cf0c9747a63c47351d1bac0bff12d2f039fec9d3831	2026-08-25 19:10:03.593102+02	2026-08-26 03:10:03.591+02	t	2026-08-27 02:01:50.664315+02	\N
153	2	22fa82541086e9425f2686b59689591d8d994e99fcca3176ff2d5ffadb7c76bf	2026-08-24 22:48:44.372195+02	2026-08-25 06:48:44.371+02	t	2026-08-27 02:01:50.664315+02	\N
174	1	4f680a68f295a10957bc4b37453c699799ca3606b9769a39c14a947c99bfeb9a	2026-08-25 22:43:11.803258+02	2026-08-26 06:43:11.803+02	t	2026-08-27 18:16:44.23273+02	\N
138	1	df29502d7b9d6107dbd5383bf9c24da1ecb29637bea6508ab2561e38780f5ed0	2026-08-24 18:08:05.007205+02	2026-08-25 02:08:05.006+02	t	2026-08-27 18:16:44.23273+02	\N
175	1	879d05ccba10c6aab55f27e342c2ac5c36806c7216dd669a56e7c7b1609df63e	2026-08-25 22:43:11.802415+02	2026-08-26 06:43:11.802+02	t	2026-08-27 18:16:44.23273+02	\N
143	1	9942e2b080f35f5c61d00ee53d6cb40af87e78d5d29a0b969b7c3f0b1c0fe5f4	2026-08-24 20:17:24.563599+02	2026-08-25 04:17:24.562+02	t	2026-08-27 18:16:44.23273+02	\N
146	1	928a48456666296aa5931332542c9d52ae00f616683725d0bf6629cecc03f76c	2026-08-24 20:59:52.839047+02	2026-08-25 04:59:52.838+02	t	2026-08-27 18:16:44.23273+02	\N
161	1	615c6c7ca594f9eb43b9715b27e047c5abed8769c5520d7b15a531e427d6be1f	2026-08-25 18:47:43.101766+02	2026-08-26 02:47:43.1+02	t	2026-08-27 18:16:44.23273+02	\N
151	1	61dbc47fcb14b80a640d8767f211196d6c514e19cee29c98b7eeecc30f675690	2026-08-24 22:26:36.964408+02	2026-08-25 06:26:36.964+02	t	2026-08-27 18:16:44.23273+02	\N
135	1	e06478d3d73b9be99cd987014c5f6f8a4bcf293f3a51d965fac5b85652620285	2026-08-24 00:11:18.657172+02	2026-08-24 08:11:18.656+02	t	2026-08-27 18:16:44.23273+02	\N
134	1	62143a397c3139ac7cf21e5e5dae8d47a7aaadd3873511695a92dfd9b4dc02ca	2026-08-23 23:14:42.529993+02	2026-08-24 07:14:42.529+02	t	2026-08-27 18:16:44.23273+02	\N
129	1	9d3e4ac5676bd268d60fbc5e2ba6ed74ba56526e9862b7e3de82bfb0d082edc7	2026-08-23 20:22:10.194335+02	2026-08-24 04:22:10.193+02	t	2026-08-27 18:16:44.23273+02	\N
137	1	ada82140f91868da035a5171c301f62dfb89c7cfca1b4f70c35e53d2cfdf490a	2026-08-24 02:11:07.261782+02	2026-08-24 10:11:07.261+02	t	2026-08-27 18:16:44.23273+02	\N
197	2	7041bca1d22a02c1dab660624982f2f64d2ebba6c77951638ab76e6ebc2a6bfb	2026-08-27 00:21:38.571678+02	2026-08-27 08:21:38.571+02	t	2026-08-27 02:01:50.664315+02	\N
168	2	aa139924b09837b169fa369b8154902df3cfba617bfbb94348a6b87a2a9aa91c	2026-08-25 20:21:56.10951+02	2026-08-26 04:21:56.109+02	t	2026-08-27 02:01:50.664315+02	\N
163	2	068064db7f088f32036672f116981b718adab72f20fd98444813fb078a0b47f4	2026-08-25 19:10:03.604785+02	2026-08-26 03:10:03.604+02	t	2026-08-27 02:01:50.664315+02	\N
154	2	80b1c4e6aa285ed2d217816f2951e6f97c575b32d0fee396d112fb8082e7f0b3	2026-08-24 22:48:44.462433+02	2026-08-25 06:48:44.461+02	t	2026-08-27 02:01:50.664315+02	\N
193	2	cdfa71def694db29e7e6468746375a5f0b47f086aad7afb7045b22322f68fe39	2026-08-26 22:41:27.016956+02	2026-08-27 06:41:27.016+02	t	2026-08-27 02:01:50.664315+02	\N
198	2	4cca9e3a479196de670d563e37c3e30e4eca635c3063183b9e42e4ec4817f0d2	2026-08-27 02:01:50.618798+02	2026-08-27 10:01:50.618+02	t	2026-08-27 02:01:50.664315+02	\N
182	2	ba761759eeb56a58ce9f22e5bc6acf39bace88ebc8643c397e960483ef9a24b4	2026-08-26 17:37:29.227676+02	2026-08-27 01:37:29.226+02	t	2026-08-27 02:01:50.664315+02	\N
164	2	8e84122d58124ebc3b18843659cf791a44ee2ec5c0376a379f8c6a0b9500682a	2026-08-25 19:10:07.644363+02	2026-08-26 03:10:07.643+02	t	2026-08-27 02:01:50.664315+02	\N
155	2	482f03d03cce4c975b245f9a0b6418d1f5a537863111e490e8689e44d440d0d7	2026-08-24 22:48:44.46377+02	2026-08-25 06:48:44.463+02	t	2026-08-27 02:01:50.664315+02	\N
156	2	798ee279ddbbd4d2a976bfea9b13682b19102fa4138319462fa09d8330c4a4e5	2026-08-24 22:48:48.140784+02	2026-08-25 06:48:48.14+02	t	2026-08-27 02:01:50.664315+02	\N
169	2	35121aa3f3a567a5b98dc8f1bd5538541465fca5ce68d4a55c1f61d749720c2c	2026-08-25 21:27:12.601011+02	2026-08-26 05:27:12.599+02	t	2026-08-27 02:01:50.664315+02	\N
140	1	92d7a538d4278ebc3909941f884375ab50ae24af7cd80b9a7e397f7cf7f395c5	2026-08-24 19:40:03.051821+02	2026-08-25 03:40:03.051+02	t	2026-08-27 18:16:44.23273+02	\N
177	1	23df04b52ec032528882ca9dbc764aacef78d748fa1a108d927df5f749bb3061	2026-08-26 01:04:33.461282+02	2026-08-26 09:04:33.459+02	t	2026-08-27 18:16:44.23273+02	\N
194	2	12866217a2cd497679979ea149aff9492c3b077271fd60255f305ebaa6fee423	2026-08-26 22:41:27.017759+02	2026-08-27 06:41:27.017+02	t	2026-08-27 02:01:50.664315+02	\N
178	2	d3f9a9ac6cc01a9c347c5c8f7b46579ac918dbc93a14166798f645bb9708c24b	2026-08-26 01:04:34.561021+02	2026-08-26 09:04:34.559+02	t	2026-08-27 02:01:50.664315+02	\N
141	2	897a84c7c200f1111b34d859a2011ad97d25a16075c68d1117147afc5042d594	2026-08-24 20:02:44.5411+02	2026-08-25 04:02:44.539+02	t	2026-08-27 02:01:50.664315+02	\N
157	2	67c2bee0ecb996ee03cc621a0515b17488b0f72ad831c01dfb1d48bee44409f7	2026-08-25 16:44:17.362281+02	2026-08-26 00:44:17.361+02	t	2026-08-27 02:01:50.664315+02	\N
183	2	4ba7e8f51796a1e4954042b63e5bd11c35ff91e91d005c1f50597c902e6cb243	2026-08-26 17:37:34.783789+02	2026-08-27 01:37:34.783+02	t	2026-08-27 02:01:50.664315+02	\N
199	1	7b0e84cd21bee1984f5b1b92dde14dfbb9b74ac1536bb22715183d26afb3400d	2026-08-27 16:36:22.172042+02	2026-08-28 00:36:22.17+02	t	2026-08-27 18:16:44.23273+02	\N
170	1	07c75d2468c81f469c84a64d4a8521c1719fb5da0423930aedc363b3ce239ee1	2026-08-25 21:28:29.398835+02	2026-08-26 05:28:29.398+02	t	2026-08-27 18:16:44.23273+02	\N
165	1	e099f5267c8797896fb5c211225f9178618cb225577e3e1a515cdd55efa7ae7c	2026-08-25 20:10:32.544634+02	2026-08-26 04:10:32.544+02	t	2026-08-27 18:16:44.23273+02	\N
179	2	8f61e3e2df0fe39491fd321500fe5d0ca5dc5de263388b38e4b36e679a656626	2026-08-26 01:04:34.565852+02	2026-08-26 09:04:34.564+02	t	2026-08-27 02:01:50.664315+02	\N
159	2	757a89290e15e8ab016780f28e34ff9cc8144eca088474c9e3a98931fe27e971	2026-08-25 18:08:24.638836+02	2026-08-26 02:08:24.638+02	t	2026-08-27 02:01:50.664315+02	\N
172	2	d65c8471ec378bbad91300f653f9fc96ff2f4e4d328332f713cf2768ce43f3b9	2026-08-25 22:31:36.863788+02	2026-08-26 06:31:36.862+02	t	2026-08-27 02:01:50.664315+02	\N
201	1	c98f42397a099183c3dd22fd777ffc324ee5db571eb4d5022b9d3c00ce36155e	2026-08-27 18:16:44.114446+02	2026-08-28 02:16:44.113+02	t	2026-08-27 18:16:44.23273+02	\N
176	1	15039c0c969029504a2a730d21349e5430d28cde14c34aa70df57e6f424226d4	2026-08-25 22:43:15.964433+02	2026-08-26 06:43:15.964+02	t	2026-08-27 18:16:44.23273+02	\N
185	1	316c4c9d2de5e588b8c5d52a26f4be0a059080d42320b8f59b7e0294c8397640	2026-08-26 18:38:36.645517+02	2026-08-27 02:38:36.644+02	t	2026-08-27 18:16:44.23273+02	\N
144	1	6b57ac2897c1763c72dc53e803c2d53a7b440c61edcc725a157c207c1b8e34ce	2026-08-24 20:58:40.456505+02	2026-08-25 04:58:40.455+02	t	2026-08-27 18:16:44.23273+02	\N
173	2	d716019f289047762b32b5e5e4e4666d96241f0a689a8bc32e435ec8b1f0a242	2026-08-25 22:31:42.149804+02	2026-08-26 06:31:42.148+02	t	2026-08-27 02:01:50.664315+02	\N
145	2	641b145af1b83670b6fb7d446d59af180dd44569ab08355528f7521a65a9539b	2026-08-24 20:58:55.478885+02	2026-08-25 04:58:55.478+02	t	2026-08-27 02:01:50.664315+02	\N
186	2	86746dbd1acb2fda1ebe20dde1eb99744d26fe3199616782fb7fd7645bc3bcae	2026-08-26 18:41:52.265735+02	2026-08-27 02:41:52.264+02	t	2026-08-27 02:01:50.664315+02	\N
202	1	fd6a49d7315f85ff2288e33a9f2ca9d640f1ab09dfb6a86ebbbc80a47588ba18	2026-08-27 18:16:44.116515+02	2026-08-28 02:16:44.115+02	t	2026-08-27 18:16:44.23273+02	\N
160	1	f640ebba2808369a7ad114b4ffc7d992ea2babadc72c339026aca210863d7426	2026-08-25 18:47:38.047202+02	2026-08-26 02:47:38.046+02	t	2026-08-27 18:16:44.23273+02	\N
187	2	e781c9d0b41a30b8dfe83c815797466b3cd0918486e7f1642bb81d147e6c35ee	2026-08-26 21:01:08.132557+02	2026-08-27 05:01:08.132+02	t	2026-08-27 02:01:50.664315+02	\N
195	1	29832b6463f67da59a900427dad718a8c9b0b6835a5376b685b45c74dac01b7a	2026-08-26 22:48:36.138251+02	2026-08-27 06:48:36.137+02	t	2026-08-27 18:16:44.23273+02	\N
184	1	2be08c21dfd4b7c47afba8638546a49a90ef15a8d165395b59f0ce7830545fd7	2026-08-26 17:38:35.39688+02	2026-08-27 01:38:35.395+02	t	2026-08-27 18:16:44.23273+02	\N
171	1	adc130af91e852281f79318185100faac3c70e01655da14ecd4ca5cbf8c541da	2026-08-25 21:34:39.78823+02	2026-08-26 05:34:39.787+02	t	2026-08-27 18:16:44.23273+02	\N
166	1	292aeaa6b6b7b43b1e2d7180dcbf949d4c2aa96ff22f9cca5bbeb4ef0102724b	2026-08-25 20:10:32.537955+02	2026-08-26 04:10:32.537+02	t	2026-08-27 18:16:44.23273+02	\N
158	1	b4e5a45c1586bf199ded1899d2f3e6420e312f2f6ba47f222dca0b55fd490b4a	2026-08-25 16:47:28.24161+02	2026-08-26 00:47:28.241+02	t	2026-08-27 18:16:44.23273+02	\N
142	1	912f3936f8d823ec3f20104640182d077be3e0241681245588b64b3e5aa4207b	2026-08-24 20:17:21.463732+02	2026-08-25 04:17:21.463+02	t	2026-08-27 18:16:44.23273+02	\N
188	2	7515bb74176b483065d27dbf7335c92f1cefe2ca91cb37293b0783631b0daef6	2026-08-26 21:01:08.152727+02	2026-08-27 05:01:08.152+02	t	2026-08-27 02:01:50.664315+02	\N
200	1	549f835b94ce2c752cafdaf8f1b03640f54cb696c96d88a9766aa29a705f32d8	2026-08-27 18:16:44.103196+02	2026-08-28 02:16:44.102+02	t	2026-08-27 18:16:44.23273+02	\N
147	1	66c49eb7256adbae029ba495ea729388b1da1ca393cd021b04cf77143795834c	2026-08-24 21:03:47.932528+02	2026-08-25 05:03:47.931+02	t	2026-08-27 18:16:44.23273+02	\N
131	1	1781d0c516cf0c19c5f0fbe7cde8daae5eb2707502e30463e9134accd3b46f49	2026-08-23 21:29:51.317696+02	2026-08-24 05:29:51.316+02	t	2026-08-27 18:16:44.23273+02	\N
133	1	fa1e9514bfb3903024155ef263ba2ae8256765591a425cb947051457716229d0	2026-08-23 23:14:42.51612+02	2026-08-24 07:14:42.515+02	t	2026-08-27 18:16:44.23273+02	\N
128	1	7758beacb99b7daf11edc6fa08dde274e50acf81aaf9c7ecd484409a6b588ac7	2026-08-23 18:35:40.199815+02	2026-08-24 02:35:40.198+02	t	2026-08-27 18:16:44.23273+02	\N
132	1	a992bc0a0d972323108def19d5b4e10b7e5eb5243d9f3245d2ce8dc58bf4e74e	2026-08-23 21:30:04.571054+02	2026-08-24 05:30:04.57+02	t	2026-08-27 18:16:44.23273+02	\N
152	1	ae61eb9f5d0f5d8de0a5108f5aa80de6070a032ff77ebcc7917fcd6f27ad7857	2026-08-24 22:26:41.199553+02	2026-08-25 06:26:41.199+02	t	2026-08-27 18:16:44.23273+02	\N
189	2	b38c18741fe28bcdf8e48b0a826c06c23ad0513f39f8c018170193d468b8c433	2026-08-26 21:01:13.100788+02	2026-08-27 05:01:13.1+02	t	2026-08-27 02:01:50.664315+02	\N
148	1	5b01cc7dde81b9e7d8012100ef1deb25e64d00eb5e3d103d49931da9891fdce3	2026-08-24 21:04:10.650608+02	2026-08-25 05:04:10.649+02	t	2026-08-27 18:16:44.23273+02	\N
149	1	6016379bc5d059069f5138595416b70663b2c1a23645cf455c3702f27d6d70ca	2026-08-24 21:04:23.386797+02	2026-08-25 05:04:23.386+02	t	2026-08-27 18:16:44.23273+02	\N
130	1	c6582fa1e0599d05b44a320766809d884e7527d6d28e9da4c8c83d8e8934f9d3	2026-08-23 21:29:51.316269+02	2026-08-24 05:29:51.315+02	t	2026-08-27 18:16:44.23273+02	\N
136	1	f1c26589478406386bcec7ee3db45e1bd537d01d220b099814f2b35b89cb9507	2026-08-24 02:11:07.251441+02	2026-08-24 10:11:07.251+02	t	2026-08-27 18:16:44.23273+02	\N
139	1	05a858af1308ddb9e7c8451127a30fad25e5b39a244b6df5968d7bb72579ec11	2026-08-24 19:07:25.345335+02	2026-08-25 03:07:25.344+02	t	2026-08-27 18:16:44.23273+02	\N
150	1	a5fc0d722d48150f4a7fd20e2a0829b2189dc39e531cea30cb6c79a0a0ed220d	2026-08-24 21:15:13.737671+02	2026-08-25 05:15:13.737+02	t	2026-08-27 18:16:44.23273+02	\N
191	1	b930fbf96be270a1d5da9294b5efc6c25b8a549e5e302ca3c76cc548ce781a85	2026-08-26 21:05:03.022544+02	2026-08-27 05:05:03.022+02	t	2026-08-27 18:16:44.23273+02	\N
181	1	b1e78fff737fdfd3e2eb879b733a71c6a32c545d45095f917ad7981d65497d7b	2026-08-26 16:32:34.216814+02	2026-08-27 00:32:34.216+02	t	2026-08-27 18:16:44.23273+02	\N
192	1	c26cff6b6aa1421231d4e8b1d0879111e48200305dd8e6035259fa27d67b3092	2026-08-26 21:05:06.713889+02	2026-08-27 05:05:06.713+02	t	2026-08-27 18:16:44.23273+02	\N
\.


--
-- TOC entry 5452 (class 0 OID 26004)
-- Dependencies: 260
-- Data for Name: register_expenses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.register_expenses (id, session_id, store_id, amount, category, description, expense_date, is_voided, void_reason, voided_at, voided_by, created_by, created_at) FROM stdin;
1	\N	1	49980.00	other	Automatic Daily Cash Collection (AAO Sobha)	2026-08-11	f	\N	\N	\N	1	2026-08-11 06:00:05.054865+02
2	6	1	44590.00	utility	This was taken for buying a new storm by the admin.	2026-08-11	f	\N	\N	\N	3	2026-08-11 19:21:40.153949+02
3	\N	1	29874.00	other	Automatic Daily Cash Collection (AAO Sobha)	2026-08-24	f	\N	\N	\N	1	2026-08-24 06:00:04.195536+02
4	\N	2	41795.00	other	Automatic Daily Cash Collection (Kiosque Ain Meraine)	2026-08-24	f	\N	\N	\N	1	2026-08-24 06:00:04.221486+02
5	\N	1	409519.00	other	Automatic Daily Cash Collection (AAO Sobha)	2026-08-25	f	\N	\N	\N	1	2026-08-25 06:00:03.589614+02
6	\N	1	158000.00	other	Automatic Daily Cash Collection (AAO Sobha)	2026-08-26	f	\N	\N	\N	1	2026-08-26 06:00:06.459155+02
7	\N	1	58500.00	other	Automatic Daily Cash Collection (AAO Sobha)	2026-08-27	f	\N	\N	\N	1	2026-08-27 06:00:04.219042+02
\.


--
-- TOC entry 5434 (class 0 OID 17090)
-- Dependencies: 240
-- Data for Name: session_accessory_sales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_accessory_sales (id, session_id, product_id, product_name_snapshot, category_name_snapshot, price_snapshot, commission_snapshot, is_voided, voided_at, voided_by, void_reason, sold_at, real_price_snapshot, customer_id, loyalty_earned_snapshot, loyalty_redeemed_snapshot) FROM stdin;
6	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-24 22:50:27.890011+02	53000.00	50	100.00	0.00
5	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-24 22:50:15.904551+02	53000.00	50	100.00	0.00
4	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-24 22:50:08.801643+02	53000.00	50	100.00	0.00
3	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-24 22:50:02.509779+02	53000.00	50	100.00	0.00
2	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-24 22:49:48.612922+02	53000.00	50	100.00	0.00
1	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	0.00	f	\N	\N	\N	2026-08-24 21:45:30.086837+02	53000.00	50	100.00	0.00
7	8	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-24 23:15:52.700642+02	53000.00	1	100.00	200.00
8	9	1	Samsung Galaxy A56 5G 8/128	Samsung phones	55000.00	100.00	f	\N	\N	\N	2026-08-26 16:32:12.037643+02	53000.00	54	100.00	0.00
\.


--
-- TOC entry 5436 (class 0 OID 17125)
-- Dependencies: 242
-- Data for Name: session_debts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_debts (id, session_id, amount, description, is_voided, voided_at, voided_by, void_reason, entered_at, customer_id) FROM stdin;
\.


--
-- TOC entry 5430 (class 0 OID 17027)
-- Dependencies: 236
-- Data for Name: session_sim_sales; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_sim_sales (id, session_id, offer_id, offer_name_snapshot, real_price_snapshot, selling_price_snapshot, commission_points_snapshot, commission_snapshot, is_voided, voided_at, voided_by, void_reason, sold_at, customer_id, discount_snapshot, loyalty_earned_snapshot, loyalty_redeemed_snapshot) FROM stdin;
64	8	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-24 23:13:40.01453+02	50	0.00	25.00	681.00
67	9	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-25 21:36:42.444397+02	50	0.00	25.00	0.00
70	10	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-26 21:01:37.151991+02	50	0.00	25.00	0.00
48	4	16	Dima 2500	2500.00	1700.00	1250	50.00	t	2026-08-11 20:11:12.744536+02	2	Wrong Price	2026-08-11 20:10:22.604103+02	1	0.00	0.00	0.00
57	4	20	La Gold 2500	2500.00	1700.00	1250	50.00	t	2026-08-11 22:42:47.14154+02	2	000000	2026-08-11 22:30:35.535705+02	1	800.00	0.00	0.00
60	4	20	La Gold 2500	2500.00	1695.00	1250	50.00	t	2026-08-11 22:47:50.4139+02	2	Customer change his mind	2026-08-11 22:47:30.277622+02	1	805.00	0.00	0.00
39	6	27	Ooredoo POP 2000 0550	2000.00	2000.00	0	50.00	f	\N	\N	\N	2026-08-11 14:03:07.32509+02	44	0.00	0.00	0.00
42	6	27	Ooredoo POP 2000 0550	2000.00	2000.00	0	50.00	f	\N	\N	\N	2026-08-11 17:20:54.443433+02	46	0.00	0.00	0.00
62	8	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-24 21:02:55.106229+02	1	0.00	25.00	0.00
1	2	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-10 09:43:24.5968+02	4	0.00	0.00	0.00
2	2	20	La Gold 2500	2500.00	2500.00	1250	50.00	f	\N	\N	\N	2026-08-10 10:08:01.694898+02	5	0.00	25.00	0.00
3	2	19	La Gold 2000	2000.00	2000.00	500	50.00	f	\N	\N	\N	2026-08-10 10:18:25.998385+02	6	0.00	25.00	0.00
4	2	18	La Gold 1500	1500.00	1500.00	375	50.00	f	\N	\N	\N	2026-08-10 10:37:04.91794+02	1	0.00	25.00	0.00
5	3	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 11:29:28.839896+02	10	800.00	25.00	0.00
6	3	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 12:05:21.01752+02	13	800.00	25.00	0.00
7	3	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 12:17:02.166376+02	14	800.00	25.00	0.00
8	3	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-10 12:25:07.561167+02	16	0.00	0.00	0.00
9	3	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 15:58:42.496045+02	23	800.00	25.00	0.00
10	3	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 17:41:03.046541+02	26	800.00	25.00	0.00
65	9	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-25 19:39:12.773155+02	50	0.00	25.00	0.00
68	9	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-25 21:49:37.576378+02	50	0.00	25.00	0.00
71	10	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-26 21:02:58.848808+02	1	0.00	25.00	1000.00
11	3	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 19:16:45.242951+02	29	800.00	25.00	0.00
12	2	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 19:55:59.019235+02	30	800.00	25.00	0.00
13	2	16	Dima 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 20:14:43.445456+02	1	0.00	25.00	0.00
14	2	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-10 20:18:34.157797+02	1	0.00	0.00	0.00
15	2	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 21:16:08.815004+02	1	800.00	25.00	0.00
16	2	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-10 21:55:28.524013+02	1	800.00	25.00	0.00
17	5	20	La Gold 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 09:59:41.789836+02	1	1250.00	25.00	0.00
18	5	20	La Gold 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 10:00:07.503728+02	1	1250.00	25.00	0.00
19	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 10:07:23.303038+02	1	450.00	25.00	0.00
20	5	20	La Gold 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 10:31:54.037999+02	1	1250.00	25.00	0.00
21	4	16	Dima 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 10:39:13.787458+02	1	0.00	25.00	0.00
22	4	16	Dima 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 10:59:44.199988+02	1	0.00	25.00	0.00
23	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 11:02:24.074304+02	1	450.00	25.00	0.00
24	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 11:02:39.448072+02	1	450.00	25.00	0.00
25	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 11:02:55.510128+02	1	450.00	25.00	0.00
26	6	18	La Gold 1500	1500.00	1500.00	375	50.00	f	\N	\N	\N	2026-08-11 11:34:58.959122+02	1	0.00	25.00	0.00
27	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 11:44:01.60912+02	1	450.00	25.00	0.00
28	5	18	La Gold 1500	1500.00	1500.00	375	50.00	f	\N	\N	\N	2026-08-11 12:17:02.947321+02	1	0.00	25.00	0.00
29	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:17:20.656878+02	1	450.00	25.00	0.00
30	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:17:39.426261+02	1	450.00	25.00	0.00
31	6	20	La Gold 2500	2500.00	1300.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:37:40.563664+02	37	1200.00	25.00	0.00
32	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:40:33.092182+02	1	450.00	25.00	0.00
33	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:40:49.669285+02	1	450.00	25.00	0.00
34	5	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-11 12:41:03.089042+02	1	0.00	0.00	0.00
35	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:49:33.680796+02	1	450.00	25.00	0.00
36	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:53:43.102059+02	1	450.00	25.00	0.00
37	6	20	La Gold 2500	2500.00	1500.00	1250	50.00	f	\N	\N	\N	2026-08-11 12:59:06.305758+02	38	1000.00	25.00	0.00
38	6	20	La Gold 2500	2500.00	1300.00	1250	50.00	f	\N	\N	\N	2026-08-11 13:16:41.643489+02	39	1200.00	25.00	0.00
40	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 14:29:21.543567+02	1	450.00	25.00	0.00
41	5	16	Dima 2500	2500.00	1250.00	1250	50.00	f	\N	\N	\N	2026-08-11 15:37:33.994073+02	1	450.00	25.00	0.00
43	6	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-11 18:38:08.186265+02	48	0.00	0.00	0.00
44	7	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-11 19:05:18.580568+02	1	0.00	0.00	0.00
45	4	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 19:27:52.87996+02	1	800.00	25.00	0.00
46	4	18	La Gold 1500	1500.00	1500.00	375	50.00	f	\N	\N	\N	2026-08-11 19:28:03.192267+02	1	0.00	25.00	0.00
47	7	16	Dima 2500	2500.00	1300.00	1250	50.00	f	\N	\N	\N	2026-08-11 19:43:12.129108+02	1	400.00	25.00	0.00
49	4	16	Dima 2500	2500.00	1500.00	1250	50.00	f	\N	\N	\N	2026-08-11 20:11:25.079797+02	1	200.00	25.00	0.00
50	7	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-11 20:32:22.066062+02	1	0.00	0.00	0.00
51	7	16	Dima 2500	2500.00	1300.00	1250	50.00	f	\N	\N	\N	2026-08-11 20:37:58.667322+02	1	400.00	25.00	0.00
52	4	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 20:43:45.485052+02	1	800.00	25.00	0.00
53	4	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-11 20:54:02.204278+02	1	0.00	25.00	0.00
54	4	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 21:22:32.837657+02	1	800.00	25.00	0.00
55	4	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 21:22:43.353733+02	1	800.00	25.00	0.00
56	4	7	Ooredoo 500	500.00	500.00	100	50.00	f	\N	\N	\N	2026-08-11 21:23:51.339755+02	1	0.00	0.00	0.00
58	7	16	Dima 2500	2500.00	1300.00	1250	50.00	f	\N	\N	\N	2026-08-11 22:32:42.897958+02	1	400.00	25.00	0.00
59	7	16	Dima 2500	2500.00	1300.00	1250	50.00	f	\N	\N	\N	2026-08-11 22:35:56.538188+02	1	400.00	25.00	0.00
61	4	20	La Gold 2500	2500.00	1700.00	1250	50.00	f	\N	\N	\N	2026-08-11 22:48:02.059251+02	1	800.00	25.00	0.00
63	8	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-24 22:49:09.500063+02	50	0.00	25.00	0.00
66	9	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-25 21:27:27.074981+02	50	0.00	25.00	0.00
69	9	17	La Gold 1000	1000.00	1000.00	250	50.00	f	\N	\N	\N	2026-08-26 16:29:26.199716+02	52	0.00	25.00	0.00
\.


--
-- TOC entry 5432 (class 0 OID 17063)
-- Dependencies: 238
-- Data for Name: session_storm_entries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_storm_entries (id, session_id, amount, note, is_voided, voided_at, voided_by, void_reason, entered_at, customer_id, loyalty_earned_snapshot, loyalty_redeemed_snapshot) FROM stdin;
99	8	1500.00	Manual POS Entry | Phone: (0559516359)	f	\N	\N	\N	2026-08-24 23:19:32.682417+02	1	15.00	250.00
103	9	1500.00	\N	f	\N	\N	\N	2026-08-25 19:35:46.362146+02	50	15.00	0.00
64	6	160000.00	Ooredoo POP 2000	t	2026-08-11 19:18:30.193328+02	3	Wrong Amount	2026-08-11 19:18:13.383046+02	1	0.00	0.00
95	8	2500.00	Manual POS Entry | Phone: (0559516395)	f	\N	\N	\N	2026-08-24 21:47:37.208251+02	50	25.00	0.00
97	8	100.00	Manual POS Entry | Phone: (0559516395)	f	\N	\N	\N	2026-08-24 21:48:11.738018+02	50	1.00	0.00
4	2	300.00	0561298790	f	\N	\N	\N	2026-08-10 10:06:12.003307+02	1	3.00	0.00
90	8	1500.00	Manual POS Entry | Phone: (000000)	f	\N	\N	\N	2026-08-24 21:10:17.966516+02	1	15.00	0.00
91	8	1000.00	Manual POS Entry | Phone: (000000)	f	\N	\N	\N	2026-08-24 21:17:00.861235+02	1	10.00	0.00
100	9	1000.00	\N	f	\N	\N	\N	2026-08-25 17:01:33.512+02	51	10.00	0.00
104	9	1500.00	\N	f	\N	\N	\N	2026-08-25 19:37:22.055433+02	50	15.00	0.00
72	7	1500.00	Manual POS Entry | Phone: (${})	t	2026-08-11 22:51:17.837174+02	4	fffff	2026-08-11 19:44:01.988848+02	1	0.00	0.00
87	8	2000.00	000000	f	\N	\N	\N	2026-08-24 20:59:15.777648+02	\N	0.00	0.00
88	8	2500.00	000000	f	\N	\N	\N	2026-08-24 21:02:32.742422+02	\N	0.00	0.00
101	9	150000.00	\N	f	\N	\N	\N	2026-08-25 17:02:17.587947+02	51	1500.00	0.00
105	9	1500.00	\N	f	\N	\N	\N	2026-08-26 16:30:42.232669+02	53	15.00	0.00
92	8	1000.00	Manual POS Entry | Phone: (000000)	f	\N	\N	\N	2026-08-24 21:17:54.800555+02	1	10.00	0.00
93	8	1500.00	Manual POS Entry | Phone: (000000)	f	\N	\N	\N	2026-08-24 21:20:13.110591+02	1	15.00	0.00
94	8	1500.00	Manual POS Entry | Phone: (000000)	f	\N	\N	\N	2026-08-24 21:23:35.893559+02	1	15.00	0.00
1	2	500.00	USSD (*585#) Bundle | Phone: (0554198047)	f	\N	\N	\N	2026-08-10 09:25:49.812593+02	2	5.00	0.00
2	2	1500.00	USSD (*585#) Bundle | Phone: (0558802704)	f	\N	\N	\N	2026-08-10 09:29:06.651691+02	1	15.00	0.00
3	2	2000.00	USSD (*580#) Op: 39644414 | Phone: (0550907433)	f	\N	\N	\N	2026-08-10 09:31:47.309711+02	3	20.00	0.00
5	2	1000.00	USSD (*585#) Bundle | Phone: (0542511252)	f	\N	\N	\N	2026-08-10 10:12:34.562624+02	1	10.00	0.00
6	2	1175.00	USSD (*585#) Bundle | Phone: (0550684621)	f	\N	\N	\N	2026-08-10 10:33:57.311433+02	7	11.75	0.00
7	2	2000.00	USSD (*585#) Bundle | Phone: (0561444340)	f	\N	\N	\N	2026-08-10 10:41:34.596887+02	8	20.00	0.00
8	2	240.00	USSD (*580#) Op: 39813261 | Phone: (0541430600)	f	\N	\N	\N	2026-08-10 10:52:02.670008+02	1	2.40	0.00
9	2	1000.00	USSD (*585#) Bundle | Phone: (0542502749)	f	\N	\N	\N	2026-08-10 11:08:04.937112+02	9	10.00	0.00
10	3	500.00	USSD (*585#) Bundle | Phone: (0541761222)	f	\N	\N	\N	2026-08-10 11:34:01.16945+02	11	5.00	0.00
11	3	190.00	USSD (*580#) Op: 26472969 | Phone: (0551334899)	f	\N	\N	\N	2026-08-10 11:45:10.01624+02	12	1.90	0.00
12	3	500.00	USSD (*585#) Bundle | Phone: (0557772076)	f	\N	\N	\N	2026-08-10 12:20:08.519351+02	15	5.00	0.00
13	3	2000.00	USSD (*580#) Op: 26641278 | Phone: (0540218996)	f	\N	\N	\N	2026-08-10 12:38:46.728281+02	17	20.00	0.00
14	3	200.00	USSD (*580#) Op: 40154735 | Phone: (0558411398)	f	\N	\N	\N	2026-08-10 12:48:15.788611+02	18	2.00	0.00
16	3	1500.00	USSD (*585#) Bundle | Phone: (0550942244)	f	\N	\N	\N	2026-08-10 14:36:22.502288+02	20	15.00	0.00
17	3	1500.00	USSD (*585#) Bundle | Phone: (0554137333)	f	\N	\N	\N	2026-08-10 14:41:19.773189+02	21	15.00	0.00
18	3	200.00	USSD (*585#) Bundle | Phone: (0550410322)	f	\N	\N	\N	2026-08-10 14:55:22.152885+02	22	2.00	0.00
19	3	1075.00	USSD (*585#) Bundle | Phone: (0542875350)	f	\N	\N	\N	2026-08-10 17:24:47.397145+02	24	10.75	0.00
20	3	1500.00	Flexy	f	\N	\N	\N	2026-08-10 17:30:40.05765+02	25	15.00	0.00
21	3	200.00	USSD (*580#) Op: 41025044 | Phone: (0564682822)	f	\N	\N	\N	2026-08-10 17:45:37.992873+02	27	2.00	0.00
22	3	1400.00	Flexy	f	\N	\N	\N	2026-08-10 18:25:53.680978+02	28	14.00	0.00
23	3	400.00	Flexy	f	\N	\N	\N	2026-08-10 19:25:39.265686+02	1	4.00	0.00
24	2	500.00	USSD (*585#) Bundle | Phone: (0553476892)	f	\N	\N	\N	2026-08-10 19:49:44.679267+02	1	5.00	0.00
25	2	150.00	USSD (*580#) Op: 41433581 | Phone: (0551977624)	f	\N	\N	\N	2026-08-10 19:50:55.223263+02	1	1.50	0.00
26	2	200.00	USSD (*580#) Op: 41462742 | Phone: (0562651981)	f	\N	\N	\N	2026-08-10 19:59:02.426397+02	1	2.00	0.00
27	2	2000.00	USSD (*585#) Bundle | Phone: (0556409215)	f	\N	\N	\N	2026-08-10 20:08:50.380432+02	1	20.00	0.00
28	2	500.00	USSD (*580#) Op: 15380569 | Phone: (0541621932)	f	\N	\N	\N	2026-08-10 20:30:10.386452+02	1	5.00	0.00
29	2	1000.00	USSD (*585#) Bundle | Phone: (0563500123)	f	\N	\N	\N	2026-08-10 20:42:02.254551+02	1	10.00	0.00
30	5	500.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 09:44:56.874026+02	1	5.00	0.00
31	4	2598.00	USSD (*585#) Bundle | Phone: (0551008928)	f	\N	\N	\N	2026-08-11 09:48:09.32554+02	1	25.98	0.00
32	4	1098.00	USSD (*585#) Bundle | Phone: (0557124539)	f	\N	\N	\N	2026-08-11 09:53:13.655487+02	1	10.98	0.00
33	4	1598.00	USSD (*585#) Bundle | Phone: (0549541374)	f	\N	\N	\N	2026-08-11 10:05:56.458599+02	1	15.98	0.00
34	4	200.00	USSD (*585#) Bundle | Phone: (0549560878)	f	\N	\N	\N	2026-08-11 10:10:04.044313+02	1	2.00	0.00
35	5	1000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 10:22:16.706541+02	1	10.00	0.00
36	5	1000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 10:43:22.558783+02	1	10.00	0.00
37	4	1000.00	USSD (*580#) Op: 29710624 | Phone: (0556221776)	f	\N	\N	\N	2026-08-11 10:51:56.41322+02	1	10.00	0.00
38	4	100.00	USSD (*580#) Op: 240429079102 | Phone: (0561880560)	f	\N	\N	\N	2026-08-11 10:58:56.159268+02	1	1.00	0.00
39	4	500.00	USSD (*580#) Op: 29748138 | Phone: (0540878664)	f	\N	\N	\N	2026-08-11 11:06:19.530469+02	1	5.00	0.00
40	5	120.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 11:08:18.062631+02	1	1.20	0.00
41	4	100.00	flexy	f	\N	\N	\N	2026-08-11 11:12:57.472308+02	1	1.00	0.00
42	6	1075.00	USSD (*585#) Bundle | Phone: (0559379917)	f	\N	\N	\N	2026-08-11 11:27:32.498685+02	31	10.75	0.00
43	6	1575.00	USSD (*585#) Bundle | Phone: (0557689981)	f	\N	\N	\N	2026-08-11 11:36:41.893809+02	1	15.75	0.00
44	6	2000.00	USSD (*580#) Op: 17111250 | Phone: (0552129917)	f	\N	\N	\N	2026-08-11 11:37:43.550467+02	1	20.00	0.00
45	6	1000.00	USSD (*585#) Bundle | Phone: (0558704129)	f	\N	\N	\N	2026-08-11 11:39:42.977179+02	32	10.00	0.00
46	6	1000.00	USSD (*580#) Op: 17119954 | Phone: (0552284283)	f	\N	\N	\N	2026-08-11 11:41:16.072695+02	33	10.00	0.00
47	6	100.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 11:54:16.218688+02	1	1.00	0.00
48	6	100.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 11:54:25.69778+02	1	1.00	0.00
49	6	45.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 11:56:34.091031+02	1	0.45	0.00
50	6	200.00	USSD (*585#) Bundle | Phone: (0541297855)	f	\N	\N	\N	2026-08-11 12:03:20.133083+02	34	2.00	0.00
51	6	500.00	USSD (*580#) Op: 260429463050 | Phone: (0555054785)	f	\N	\N	\N	2026-08-11 12:05:04.866629+02	35	5.00	0.00
52	5	2000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 12:16:39.384608+02	1	20.00	0.00
53	6	2000.00	USSD (*585#) Bundle | Phone: (0559184224)	f	\N	\N	\N	2026-08-11 12:32:37.228606+02	36	20.00	0.00
54	5	1000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 13:06:59.104048+02	1	10.00	0.00
55	5	2000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 13:12:47.638801+02	1	20.00	0.00
96	8	1550.00	Manual POS Entry | Phone: (0559516395)	f	\N	\N	\N	2026-08-24 21:47:51.420414+02	50	15.50	0.00
85	8	2000.00	Storm Recharge	f	\N	\N	\N	2026-08-24 20:03:03.431442+02	1	20.00	0.00
86	8	1500.00	Storm	f	\N	\N	\N	2026-08-24 20:18:47.455318+02	1	15.00	0.00
89	8	1000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-24 21:07:03.270852+02	1	10.00	0.00
15	3	250.00	Flexy	f	\N	\N	\N	2026-08-10 14:08:58.32991+02	19	2.50	0.00
56	6	200.00	USSD (*580#) Op: 30159488 | Phone: (0555775287)	f	\N	\N	\N	2026-08-11 13:20:33.992586+02	40	2.00	0.00
57	5	100.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 13:44:25.932178+02	1	1.00	0.00
58	6	200.00	USSD (*580#) Op: 30250784 | Phone: (0551889569)	f	\N	\N	\N	2026-08-11 13:48:56.98681+02	41	2.00	0.00
59	6	500.00	USSD (*580#) Op: 17522420 | Phone: (0558774111)	f	\N	\N	\N	2026-08-11 13:49:44.62228+02	42	5.00	0.00
60	6	200.00	USSD (*580#) Op: 260429506914 | Phone: (0551354082)	f	\N	\N	\N	2026-08-11 13:54:54.798995+02	43	2.00	0.00
61	6	1000.00	Flexy	f	\N	\N	\N	2026-08-11 14:07:19.98075+02	45	10.00	0.00
62	6	230.00	USSD (*580#) Op: 240429214520 | Phone: (0552962015)	f	\N	\N	\N	2026-08-11 17:25:41.995483+02	47	2.30	0.00
63	6	500.00	USSD (*585#) Bundle | Phone: (0564047237)	f	\N	\N	\N	2026-08-11 18:39:37.387416+02	49	5.00	0.00
65	6	16000.00	Ooredoo POP 2000 1 Year Avance	f	\N	\N	\N	2026-08-11 19:19:00.751841+02	1	160.00	0.00
66	4	500.00	USSD (*580#) Op: 240429266011 | Phone: (0561351086)	f	\N	\N	\N	2026-08-11 19:30:42.705289+02	1	5.00	0.00
67	4	75.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 19:30:56.071461+02	1	0.75	0.00
68	4	100.00	USSD (*580#) Op: 18707538 | Phone: (0561351086)	f	\N	\N	\N	2026-08-11 19:32:03.766696+02	1	1.00	0.00
69	4	1500.00	USSD (*585#) Bundle | Phone: (0549824391)	f	\N	\N	\N	2026-08-11 19:33:36.036867+02	1	15.00	0.00
70	7	1000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 19:43:35.175101+02	1	10.00	0.00
71	7	500.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 19:43:49.461898+02	1	5.00	0.00
73	4	2000.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 19:51:26.437528+02	1	20.00	0.00
74	4	500.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 19:55:10.224183+02	1	5.00	0.00
75	7	2075.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 20:07:26.880822+02	1	20.75	0.00
76	7	1750.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 20:18:27.705548+02	1	17.50	0.00
77	4	1220.00	USSD (*585#) Bundle | Phone: (0553210989)	f	\N	\N	\N	2026-08-11 20:24:16.407498+02	1	12.20	0.00
78	7	550.00	Manual POS Entry | Phone: (${})	f	\N	\N	\N	2026-08-11 20:40:38.887879+02	1	5.50	0.00
79	4	200.00	USSD (*585#) Bundle | Phone: (0564027762)	f	\N	\N	\N	2026-08-11 20:49:56.613884+02	1	2.00	0.00
80	4	150.00	USSD (*580#) Op: 18992838 | Phone: (0564673234)	f	\N	\N	\N	2026-08-11 20:53:36.989314+02	1	1.50	0.00
81	4	1500.00	USSD (*585#) Bundle | Phone: (0551237532)	f	\N	\N	\N	2026-08-11 20:54:35.586632+02	1	15.00	0.00
82	4	1500.00	USSD (*585#) Bundle | Phone: (0550410322)	f	\N	\N	\N	2026-08-11 21:25:03.158477+02	22	15.00	0.00
83	4	1600.00	USSD (*580#) Op: 220589612201 | Phone: (0561427799)	f	\N	\N	\N	2026-08-11 21:49:13.441878+02	1	16.00	0.00
84	4	1500.00	USSD (*585#) Bundle | Phone: (0553902614)	f	\N	\N	\N	2026-08-11 22:11:27.051026+02	1	15.00	0.00
98	8	1500.00	Manual POS Entry | Phone: (0559516395)	f	\N	\N	\N	2026-08-24 22:49:34.739869+02	50	15.00	0.00
102	9	755.00	\N	f	\N	\N	\N	2026-08-25 17:02:47.093121+02	51	7.55	1510.00
\.


--
-- TOC entry 5457 (class 0 OID 66964)
-- Dependencies: 265
-- Data for Name: sim_balances; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sim_balances (id, owner_type, owner_id, quantity) FROM stdin;
1	admin	1	0
4	store	2	500
3	store	1	497
\.


--
-- TOC entry 5440 (class 0 OID 17178)
-- Dependencies: 246
-- Data for Name: store_register_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.store_register_state (id, store_id, cash_amount, updated_at, updated_by, notes) FROM stdin;
1	1	500.00	2026-08-10 09:25:49.812593+02	2	Storm Sale (Session 2)
2	1	2000.00	2026-08-10 09:29:06.651691+02	2	Storm Sale (Session 2)
3	1	4000.00	2026-08-10 09:31:47.309711+02	2	Storm Sale (Session 2)
4	1	4500.00	2026-08-10 09:43:24.5968+02	2	SIM Sale (Session 2)
5	1	4800.00	2026-08-10 10:06:12.003307+02	2	Storm Sale (Session 2)
6	1	7300.00	2026-08-10 10:08:01.694898+02	2	SIM Sale (Session 2)
7	1	8300.00	2026-08-10 10:12:34.562624+02	2	Storm Sale (Session 2)
8	1	10300.00	2026-08-10 10:18:25.998385+02	2	SIM Sale (Session 2)
9	1	11475.00	2026-08-10 10:33:57.311433+02	2	Storm Sale (Session 2)
10	1	12975.00	2026-08-10 10:37:04.91794+02	2	SIM Sale (Session 2)
11	1	14975.00	2026-08-10 10:41:34.596887+02	2	Storm Sale (Session 2)
12	1	15215.00	2026-08-10 10:52:02.670008+02	2	Storm Sale (Session 2)
13	1	16215.00	2026-08-10 11:08:04.937112+02	2	Storm Sale (Session 2)
14	1	17915.00	2026-08-10 11:29:28.839896+02	3	SIM Sale (Session 3)
15	1	18415.00	2026-08-10 11:34:01.16945+02	3	Storm Sale (Session 3)
16	1	18605.00	2026-08-10 11:45:10.01624+02	3	Storm Sale (Session 3)
17	1	20305.00	2026-08-10 12:05:21.01752+02	3	SIM Sale (Session 3)
18	1	22005.00	2026-08-10 12:17:02.166376+02	3	SIM Sale (Session 3)
19	1	22505.00	2026-08-10 12:20:08.519351+02	3	Storm Sale (Session 3)
20	1	23005.00	2026-08-10 12:25:07.561167+02	3	SIM Sale (Session 3)
21	1	25005.00	2026-08-10 12:38:46.728281+02	3	Storm Sale (Session 3)
22	1	25205.00	2026-08-10 12:48:15.788611+02	3	Storm Sale (Session 3)
23	1	25455.00	2026-08-10 14:08:58.32991+02	3	Storm Sale (Session 3)
24	1	26955.00	2026-08-10 14:36:22.502288+02	3	Storm Sale (Session 3)
25	1	28455.00	2026-08-10 14:41:19.773189+02	3	Storm Sale (Session 3)
26	1	28655.00	2026-08-10 14:55:22.152885+02	3	Storm Sale (Session 3)
27	1	30355.00	2026-08-10 15:58:42.496045+02	3	SIM Sale (Session 3)
28	1	31430.00	2026-08-10 17:24:47.397145+02	3	Storm Sale (Session 3)
29	1	32930.00	2026-08-10 17:30:40.05765+02	3	Storm Sale (Session 3)
30	1	34630.00	2026-08-10 17:41:03.046541+02	3	SIM Sale (Session 3)
31	1	34830.00	2026-08-10 17:45:37.992873+02	3	Storm Sale (Session 3)
32	1	36230.00	2026-08-10 18:25:53.680978+02	3	Storm Sale (Session 3)
33	1	37930.00	2026-08-10 19:16:45.242951+02	3	SIM Sale (Session 3)
34	1	38330.00	2026-08-10 19:25:39.265686+02	3	Storm Sale (Session 3)
35	1	38830.00	2026-08-10 19:49:44.679267+02	2	Storm Sale (Session 2)
36	1	38980.00	2026-08-10 19:50:55.223263+02	2	Storm Sale (Session 2)
37	1	40680.00	2026-08-10 19:55:59.019235+02	2	SIM Sale (Session 2)
38	1	40880.00	2026-08-10 19:59:02.426397+02	2	Storm Sale (Session 2)
39	1	42880.00	2026-08-10 20:08:50.380432+02	2	Storm Sale (Session 2)
40	1	44580.00	2026-08-10 20:14:43.445456+02	2	SIM Sale (Session 2)
41	1	45080.00	2026-08-10 20:18:34.157797+02	2	SIM Sale (Session 2)
42	1	45580.00	2026-08-10 20:30:10.386452+02	2	Storm Sale (Session 2)
43	1	46580.00	2026-08-10 20:42:02.254551+02	2	Storm Sale (Session 2)
44	1	48280.00	2026-08-10 21:16:08.815004+02	2	SIM Sale (Session 2)
45	1	49980.00	2026-08-10 21:55:28.524013+02	2	SIM Sale (Session 2)
46	1	0.00	2026-08-11 06:00:05.054865+02	1	Auto-swept to expense #1
47	2	500.00	2026-08-11 09:44:56.874026+02	5	Storm Sale (Session 5)
48	1	2598.00	2026-08-11 09:48:09.32554+02	2	Storm Sale (Session 4)
49	1	3696.00	2026-08-11 09:53:13.655487+02	2	Storm Sale (Session 4)
50	2	1750.00	2026-08-11 09:59:41.789836+02	5	SIM Sale (Session 5)
51	2	3000.00	2026-08-11 10:00:07.503728+02	5	SIM Sale (Session 5)
52	1	5294.00	2026-08-11 10:05:56.458599+02	2	Storm Sale (Session 4)
53	2	4250.00	2026-08-11 10:07:23.303038+02	5	SIM Sale (Session 5)
54	1	5494.00	2026-08-11 10:10:04.044313+02	2	Storm Sale (Session 4)
55	2	5250.00	2026-08-11 10:22:16.706541+02	5	Storm Sale (Session 5)
56	2	6500.00	2026-08-11 10:31:54.037999+02	5	SIM Sale (Session 5)
57	1	7194.00	2026-08-11 10:39:13.787458+02	2	SIM Sale (Session 4)
58	2	7500.00	2026-08-11 10:43:22.558783+02	5	Storm Sale (Session 5)
59	1	8194.00	2026-08-11 10:51:56.41322+02	2	Storm Sale (Session 4)
60	1	8294.00	2026-08-11 10:58:56.159268+02	2	Storm Sale (Session 4)
61	1	9994.00	2026-08-11 10:59:44.199988+02	2	SIM Sale (Session 4)
62	2	8750.00	2026-08-11 11:02:24.074304+02	5	SIM Sale (Session 5)
63	2	10000.00	2026-08-11 11:02:39.448072+02	5	SIM Sale (Session 5)
64	2	11250.00	2026-08-11 11:02:55.510128+02	5	SIM Sale (Session 5)
65	1	10494.00	2026-08-11 11:06:19.530469+02	2	Storm Sale (Session 4)
66	2	11370.00	2026-08-11 11:08:18.062631+02	5	Storm Sale (Session 5)
67	1	10594.00	2026-08-11 11:12:57.472308+02	2	Storm Sale (Session 4)
68	1	11669.00	2026-08-11 11:27:32.498685+02	3	Storm Sale (Session 6)
69	1	13169.00	2026-08-11 11:34:58.959122+02	3	SIM Sale (Session 6)
70	1	14744.00	2026-08-11 11:36:41.893809+02	3	Storm Sale (Session 6)
71	1	16744.00	2026-08-11 11:37:43.550467+02	3	Storm Sale (Session 6)
72	1	17744.00	2026-08-11 11:39:42.977179+02	3	Storm Sale (Session 6)
73	1	18744.00	2026-08-11 11:41:16.072695+02	3	Storm Sale (Session 6)
74	2	12620.00	2026-08-11 11:44:01.60912+02	5	SIM Sale (Session 5)
75	1	18844.00	2026-08-11 11:54:16.218688+02	3	Storm Sale (Session 6)
76	1	18944.00	2026-08-11 11:54:25.69778+02	3	Storm Sale (Session 6)
77	1	18989.00	2026-08-11 11:56:34.091031+02	3	Storm Sale (Session 6)
78	1	19189.00	2026-08-11 12:03:20.133083+02	3	Storm Sale (Session 6)
79	1	19689.00	2026-08-11 12:05:04.866629+02	3	Storm Sale (Session 6)
80	2	14620.00	2026-08-11 12:16:39.384608+02	5	Storm Sale (Session 5)
81	2	16120.00	2026-08-11 12:17:02.947321+02	5	SIM Sale (Session 5)
82	2	17370.00	2026-08-11 12:17:20.656878+02	5	SIM Sale (Session 5)
83	2	18620.00	2026-08-11 12:17:39.426261+02	5	SIM Sale (Session 5)
84	1	21689.00	2026-08-11 12:32:37.228606+02	3	Storm Sale (Session 6)
85	1	22989.00	2026-08-11 12:37:40.563664+02	3	SIM Sale (Session 6)
86	2	19870.00	2026-08-11 12:40:33.092182+02	5	SIM Sale (Session 5)
87	2	21120.00	2026-08-11 12:40:49.669285+02	5	SIM Sale (Session 5)
88	2	21620.00	2026-08-11 12:41:03.089042+02	5	SIM Sale (Session 5)
89	2	22870.00	2026-08-11 12:49:33.680796+02	5	SIM Sale (Session 5)
90	2	24120.00	2026-08-11 12:53:43.102059+02	5	SIM Sale (Session 5)
91	1	24489.00	2026-08-11 12:59:06.305758+02	3	SIM Sale (Session 6)
92	2	25120.00	2026-08-11 13:06:59.104048+02	5	Storm Sale (Session 5)
93	2	27120.00	2026-08-11 13:12:47.638801+02	5	Storm Sale (Session 5)
94	1	25789.00	2026-08-11 13:16:41.643489+02	3	SIM Sale (Session 6)
95	1	25989.00	2026-08-11 13:20:33.992586+02	3	Storm Sale (Session 6)
96	2	27220.00	2026-08-11 13:44:25.932178+02	5	Storm Sale (Session 5)
97	1	26189.00	2026-08-11 13:48:56.98681+02	3	Storm Sale (Session 6)
98	1	26689.00	2026-08-11 13:49:44.62228+02	3	Storm Sale (Session 6)
99	1	26889.00	2026-08-11 13:54:54.798995+02	3	Storm Sale (Session 6)
100	1	28889.00	2026-08-11 14:03:07.32509+02	3	SIM Sale (Session 6)
101	1	29889.00	2026-08-11 14:07:19.98075+02	3	Storm Sale (Session 6)
102	2	28470.00	2026-08-11 14:29:21.543567+02	5	SIM Sale (Session 5)
103	2	29720.00	2026-08-11 15:37:33.994073+02	5	SIM Sale (Session 5)
104	1	31889.00	2026-08-11 17:20:54.443433+02	3	SIM Sale (Session 6)
105	1	32119.00	2026-08-11 17:25:41.995483+02	3	Storm Sale (Session 6)
106	1	32619.00	2026-08-11 18:38:08.186265+02	3	SIM Sale (Session 6)
107	1	33119.00	2026-08-11 18:39:37.387416+02	3	Storm Sale (Session 6)
108	2	30220.00	2026-08-11 19:05:18.580568+02	4	SIM Sale (Session 7)
109	1	193119.00	2026-08-11 19:18:13.383046+02	3	Storm Sale (Session 6)
110	1	33119.00	2026-08-11 19:18:30.193328+02	3	Voided storm transaction (ID 64)
111	1	49119.00	2026-08-11 19:19:00.751841+02	3	Storm Sale (Session 6)
112	1	4529.00	2026-08-11 19:21:40.153949+02	3	Register expense #2: This was taken for buying a new storm by the admin.
113	1	6229.00	2026-08-11 19:27:52.87996+02	2	SIM Sale (Session 4)
114	1	7729.00	2026-08-11 19:28:03.192267+02	2	SIM Sale (Session 4)
115	1	8229.00	2026-08-11 19:30:42.705289+02	2	Storm Sale (Session 4)
116	1	8304.00	2026-08-11 19:30:56.071461+02	2	Storm Sale (Session 4)
117	1	8404.00	2026-08-11 19:32:03.766696+02	2	Storm Sale (Session 4)
118	1	9904.00	2026-08-11 19:33:36.036867+02	2	Storm Sale (Session 4)
119	2	31520.00	2026-08-11 19:43:12.129108+02	4	SIM Sale (Session 7)
120	2	32520.00	2026-08-11 19:43:35.175101+02	4	Storm Sale (Session 7)
121	2	33020.00	2026-08-11 19:43:49.461898+02	4	Storm Sale (Session 7)
122	2	34520.00	2026-08-11 19:44:01.988848+02	4	Storm Sale (Session 7)
123	1	11904.00	2026-08-11 19:51:26.437528+02	2	Storm Sale (Session 4)
124	1	12404.00	2026-08-11 19:55:10.224183+02	2	Storm Sale (Session 4)
125	2	36595.00	2026-08-11 20:07:26.880822+02	4	Storm Sale (Session 7)
126	1	14104.00	2026-08-11 20:10:22.604103+02	2	SIM Sale (Session 4)
127	1	12404.00	2026-08-11 20:11:12.744536+02	2	Voided sim transaction (ID 48)
128	1	13904.00	2026-08-11 20:11:25.079797+02	2	SIM Sale (Session 4)
129	2	38345.00	2026-08-11 20:18:27.705548+02	4	Storm Sale (Session 7)
130	1	15124.00	2026-08-11 20:24:16.407498+02	2	Storm Sale (Session 4)
131	2	38845.00	2026-08-11 20:32:22.066062+02	4	SIM Sale (Session 7)
132	2	40145.00	2026-08-11 20:37:58.667322+02	4	SIM Sale (Session 7)
133	2	40695.00	2026-08-11 20:40:38.887879+02	4	Storm Sale (Session 7)
134	1	16824.00	2026-08-11 20:43:45.485052+02	2	SIM Sale (Session 4)
135	1	17024.00	2026-08-11 20:49:56.613884+02	2	Storm Sale (Session 4)
136	1	17174.00	2026-08-11 20:53:36.989314+02	2	Storm Sale (Session 4)
137	1	18174.00	2026-08-11 20:54:02.204278+02	2	SIM Sale (Session 4)
138	1	19674.00	2026-08-11 20:54:35.586632+02	2	Storm Sale (Session 4)
139	1	21374.00	2026-08-11 21:22:32.837657+02	2	SIM Sale (Session 4)
140	1	23074.00	2026-08-11 21:22:43.353733+02	2	SIM Sale (Session 4)
141	1	23574.00	2026-08-11 21:23:51.339755+02	2	SIM Sale (Session 4)
142	1	25074.00	2026-08-11 21:25:03.158477+02	2	Storm Sale (Session 4)
143	1	26674.00	2026-08-11 21:49:13.441878+02	2	Storm Sale (Session 4)
144	1	28174.00	2026-08-11 22:11:27.051026+02	2	Storm Sale (Session 4)
145	1	29874.00	2026-08-11 22:30:35.535705+02	2	SIM Sale (Session 4)
146	2	41995.00	2026-08-11 22:32:42.897958+02	4	SIM Sale (Session 7)
147	2	43295.00	2026-08-11 22:35:56.538188+02	4	SIM Sale (Session 7)
148	1	28174.00	2026-08-11 22:42:47.14154+02	2	Voided sim transaction (ID 57)
149	1	29869.00	2026-08-11 22:47:30.277622+02	2	SIM Sale (Session 4)
150	1	28174.00	2026-08-11 22:47:50.4139+02	2	Voided sim transaction (ID 60)
151	1	29874.00	2026-08-11 22:48:02.059251+02	2	SIM Sale (Session 4)
152	2	41795.00	2026-08-11 22:51:17.837174+02	4	Voided storm transaction (ID 72)
153	1	0.00	2026-08-24 06:00:04.195536+02	1	Auto-swept to expense #3
154	2	0.00	2026-08-24 06:00:04.221486+02	1	Auto-swept to expense #4
155	1	2000.00	2026-08-24 20:03:03.431442+02	2	Storm Sale (Session 8)
156	1	3500.00	2026-08-24 20:18:47.455318+02	2	Storm Sale (Session 8)
157	1	5500.00	2026-08-24 20:59:15.777648+02	2	Storm Sale (Session 8)
158	1	8000.00	2026-08-24 21:02:32.742422+02	2	Storm Sale (Session 8)
159	1	9000.00	2026-08-24 21:02:55.106229+02	2	SIM Sale (Session 8)
160	1	10000.00	2026-08-24 21:07:03.270852+02	2	Storm Sale (Session 8)
161	1	11500.00	2026-08-24 21:10:17.966516+02	2	Storm Sale (Session 8)
162	1	12500.00	2026-08-24 21:17:00.861235+02	2	Storm Sale (Session 8)
163	1	13500.00	2026-08-24 21:17:54.800555+02	2	Storm Sale (Session 8)
164	1	15000.00	2026-08-24 21:20:13.110591+02	2	Storm Sale (Session 8)
165	1	16500.00	2026-08-24 21:23:35.893559+02	2	Storm Sale (Session 8)
166	1	71500.00	2026-08-24 21:45:30.086837+02	2	Accessory Sale
167	1	74000.00	2026-08-24 21:47:37.208251+02	2	Storm Sale (Session 8)
168	1	75550.00	2026-08-24 21:47:51.420414+02	2	Storm Sale (Session 8)
169	1	75650.00	2026-08-24 21:48:11.738018+02	2	Storm Sale (Session 8)
170	1	76650.00	2026-08-24 22:49:09.500063+02	2	SIM Sale (Session 8)
171	1	78150.00	2026-08-24 22:49:34.739869+02	2	Storm Sale (Session 8)
172	1	133150.00	2026-08-24 22:49:48.612922+02	2	Accessory Sale
173	1	188150.00	2026-08-24 22:50:02.509779+02	2	Accessory Sale
174	1	243150.00	2026-08-24 22:50:08.801643+02	2	Accessory Sale
175	1	298150.00	2026-08-24 22:50:15.904551+02	2	Accessory Sale
176	1	353150.00	2026-08-24 22:50:27.890011+02	2	Accessory Sale
177	1	353469.00	2026-08-24 23:13:40.01453+02	2	SIM Sale (Session 8)
178	1	408269.00	2026-08-24 23:15:52.700642+02	2	Accessory Sale
179	1	409519.00	2026-08-24 23:19:32.682417+02	2	Storm Sale (Session 8)
180	1	0.00	2026-08-25 06:00:03.589614+02	1	Auto-swept to expense #5
181	1	1000.00	2026-08-25 17:01:33.512+02	2	Storm Sale (Session 9)
182	1	151000.00	2026-08-25 17:02:17.587947+02	2	Storm Sale (Session 9)
183	1	151000.00	2026-08-25 17:02:47.093121+02	2	Storm Sale (Session 9)
184	1	152500.00	2026-08-25 19:35:46.362146+02	2	Storm Sale (Session 9)
185	1	154000.00	2026-08-25 19:37:22.055433+02	2	Storm Sale (Session 9)
186	1	155000.00	2026-08-25 19:39:12.773155+02	2	SIM Sale (Session 9)
187	1	156000.00	2026-08-25 21:27:27.074981+02	2	SIM Sale (Session 9)
188	1	157000.00	2026-08-25 21:36:42.444397+02	2	SIM Sale (Session 9)
189	1	158000.00	2026-08-25 21:49:37.576378+02	2	SIM Sale (Session 9)
190	1	0.00	2026-08-26 06:00:06.459155+02	1	Auto-swept to expense #6
191	1	1000.00	2026-08-26 16:29:26.199716+02	2	SIM Sale (Session 9)
192	1	2500.00	2026-08-26 16:30:42.232669+02	2	Storm Sale (Session 9)
193	1	57500.00	2026-08-26 16:32:12.037643+02	2	Accessory Sale
194	1	58500.00	2026-08-26 21:01:37.151991+02	2	SIM Sale (Session 10)
195	1	58500.00	2026-08-26 21:02:58.848808+02	2	SIM Sale (Session 10)
196	1	0.00	2026-08-27 06:00:04.219042+02	1	Auto-swept to expense #7
\.


--
-- TOC entry 5416 (class 0 OID 16826)
-- Dependencies: 222
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stores (id, name, location, is_active, created_at) FROM stdin;
1	AAO Sobha	Sobha, Algeria	t	2026-08-09 20:01:08.487617+02
2	Kiosque Ain Meraine	Ain Meraine, Algeria	t	2026-08-09 20:01:08.487617+02
\.


--
-- TOC entry 5418 (class 0 OID 16841)
-- Dependencies: 224
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, username, password_hash, full_name, role, store_id, is_active, created_at, updated_at) FROM stdin;
1	admin	$2a$12$v3WdqsY9PNB3gItcy6PaveUqGe5EIziM8MYRaMjRKJs6OKRopxbw6	System Administrator	admin	\N	t	2026-05-14 21:29:41.537+02	2026-05-14 21:29:41.537+02
2	aymen_sobha	$2a$12$FMWWfjODNukoKXkSuZuK..jQn/4sn2oTQd.GwW7UAyQs/6DmyThvq	Aymen	cashier	1	t	2026-08-09 21:38:43.616414+02	2026-08-09 21:38:43.616414+02
3	fatiha_sobha	$2a$12$H7NFLPjE2.VJru7qjYjOQurLalMAOz0PX2jOHuSg2K1e3CObYIihG	Fatiha	cashier	1	t	2026-08-09 21:39:00.824452+02	2026-08-09 21:39:00.824452+02
4	aziz_ainmeraine	$2a$12$DeplGsTlo/k6RtcyTP06NeSdfbEszyPNS3A0NkK3E6.T1jUAyhwVe	Aziz	cashier	2	t	2026-08-09 21:39:20.907615+02	2026-08-09 21:39:20.907615+02
5	hadil_ainmeraine	$2a$12$ZLrsEZGHNAx4iF3lN0r2s.r1/LtXJIGfccb7p2UGgGqKFh6Rv99iS	Hadil	cashier	2	t	2026-08-09 21:39:42.762479+02	2026-08-09 21:39:42.762479+02
6	sarri_ainmeraine	$2a$12$PhicXYBw5immRColGow6YuhtkcC8.z2F957Bm.XVHGsE51.5ZsFjO	Sarri	cashier	2	t	2026-08-09 21:40:24.807782+02	2026-08-09 21:40:24.807782+02
\.


--
-- TOC entry 5521 (class 0 OID 0)
-- Dependencies: 249
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_id_seq', 703, true);


--
-- TOC entry 5522 (class 0 OID 0)
-- Dependencies: 257
-- Name: cashier_advances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cashier_advances_id_seq', 1, false);


--
-- TOC entry 5523 (class 0 OID 0)
-- Dependencies: 233
-- Name: cashier_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cashier_sessions_id_seq', 10, true);


--
-- TOC entry 5524 (class 0 OID 0)
-- Dependencies: 255
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 54, true);


--
-- TOC entry 5525 (class 0 OID 0)
-- Dependencies: 247
-- Name: daily_reports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.daily_reports_id_seq', 6, true);


--
-- TOC entry 5526 (class 0 OID 0)
-- Dependencies: 243
-- Name: global_pool_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.global_pool_state_id_seq', 72, true);


--
-- TOC entry 5527 (class 0 OID 0)
-- Dependencies: 262
-- Name: loyalty_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loyalty_ledger_id_seq', 45, true);


--
-- TOC entry 5528 (class 0 OID 0)
-- Dependencies: 253
-- Name: offer_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.offer_categories_id_seq', 7, true);


--
-- TOC entry 5529 (class 0 OID 0)
-- Dependencies: 227
-- Name: offers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.offers_id_seq', 30, true);


--
-- TOC entry 5530 (class 0 OID 0)
-- Dependencies: 229
-- Name: product_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_categories_id_seq', 6, true);


--
-- TOC entry 5531 (class 0 OID 0)
-- Dependencies: 231
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_id_seq', 501, true);


--
-- TOC entry 5532 (class 0 OID 0)
-- Dependencies: 225
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.refresh_tokens_id_seq', 202, true);


--
-- TOC entry 5533 (class 0 OID 0)
-- Dependencies: 259
-- Name: register_expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.register_expenses_id_seq', 7, true);


--
-- TOC entry 5534 (class 0 OID 0)
-- Dependencies: 239
-- Name: session_accessory_sales_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.session_accessory_sales_id_seq', 8, true);


--
-- TOC entry 5535 (class 0 OID 0)
-- Dependencies: 241
-- Name: session_debts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.session_debts_id_seq', 1, false);


--
-- TOC entry 5536 (class 0 OID 0)
-- Dependencies: 235
-- Name: session_sim_sales_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.session_sim_sales_id_seq', 71, true);


--
-- TOC entry 5537 (class 0 OID 0)
-- Dependencies: 237
-- Name: session_storm_entries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.session_storm_entries_id_seq', 105, true);


--
-- TOC entry 5538 (class 0 OID 0)
-- Dependencies: 264
-- Name: sim_balances_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sim_balances_id_seq', 12, true);


--
-- TOC entry 5539 (class 0 OID 0)
-- Dependencies: 245
-- Name: store_register_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.store_register_state_id_seq', 196, true);


--
-- TOC entry 5540 (class 0 OID 0)
-- Dependencies: 221
-- Name: stores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stores_id_seq', 2, true);


--
-- TOC entry 5541 (class 0 OID 0)
-- Dependencies: 223
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 6, true);


--
-- TOC entry 5176 (class 2606 OID 17263)
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 5191 (class 2606 OID 25979)
-- Name: cashier_advances cashier_advances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_advances
    ADD CONSTRAINT cashier_advances_pkey PRIMARY KEY (id);


--
-- TOC entry 5134 (class 2606 OID 16981)
-- Name: cashier_sessions cashier_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_sessions
    ADD CONSTRAINT cashier_sessions_pkey PRIMARY KEY (id);


--
-- TOC entry 5185 (class 2606 OID 17462)
-- Name: customers customers_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 5187 (class 2606 OID 17460)
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- TOC entry 5170 (class 2606 OID 17237)
-- Name: daily_reports daily_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_pkey PRIMARY KEY (id);


--
-- TOC entry 5164 (class 2606 OID 17171)
-- Name: global_pool_state global_pool_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_pool_state
    ADD CONSTRAINT global_pool_state_pkey PRIMARY KEY (id);


--
-- TOC entry 5201 (class 2606 OID 66938)
-- Name: loyalty_ledger loyalty_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_ledger
    ADD CONSTRAINT loyalty_ledger_pkey PRIMARY KEY (id);


--
-- TOC entry 5199 (class 2606 OID 66917)
-- Name: loyalty_settings loyalty_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_settings
    ADD CONSTRAINT loyalty_settings_pkey PRIMARY KEY (key);


--
-- TOC entry 5181 (class 2606 OID 17434)
-- Name: offer_categories offer_categories_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offer_categories
    ADD CONSTRAINT offer_categories_name_key UNIQUE (name);


--
-- TOC entry 5183 (class 2606 OID 17432)
-- Name: offer_categories offer_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offer_categories
    ADD CONSTRAINT offer_categories_pkey PRIMARY KEY (id);


--
-- TOC entry 5120 (class 2606 OID 16920)
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (id);


--
-- TOC entry 5174 (class 2606 OID 17239)
-- Name: daily_reports one_report_per_store_per_day; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT one_report_per_store_per_day UNIQUE (report_date, store_id);


--
-- TOC entry 5140 (class 2606 OID 16983)
-- Name: cashier_sessions one_session_per_cashier_per_day; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_sessions
    ADD CONSTRAINT one_session_per_cashier_per_day UNIQUE (cashier_id, session_date);


--
-- TOC entry 5122 (class 2606 OID 16935)
-- Name: product_categories product_categories_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_name_key UNIQUE (name);


--
-- TOC entry 5124 (class 2606 OID 16933)
-- Name: product_categories product_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT product_categories_pkey PRIMARY KEY (id);


--
-- TOC entry 5130 (class 2606 OID 58858)
-- Name: products products_barcode_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_barcode_key UNIQUE (barcode);


--
-- TOC entry 5132 (class 2606 OID 16958)
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- TOC entry 5112 (class 2606 OID 16883)
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- TOC entry 5114 (class 2606 OID 16885)
-- Name: refresh_tokens refresh_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_hash_key UNIQUE (token_hash);


--
-- TOC entry 5197 (class 2606 OID 26024)
-- Name: register_expenses register_expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.register_expenses
    ADD CONSTRAINT register_expenses_pkey PRIMARY KEY (id);


--
-- TOC entry 5157 (class 2606 OID 17108)
-- Name: session_accessory_sales session_accessory_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_accessory_sales
    ADD CONSTRAINT session_accessory_sales_pkey PRIMARY KEY (id);


--
-- TOC entry 5162 (class 2606 OID 17140)
-- Name: session_debts session_debts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_debts
    ADD CONSTRAINT session_debts_pkey PRIMARY KEY (id);


--
-- TOC entry 5146 (class 2606 OID 17046)
-- Name: session_sim_sales session_sim_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_sim_sales
    ADD CONSTRAINT session_sim_sales_pkey PRIMARY KEY (id);


--
-- TOC entry 5151 (class 2606 OID 17078)
-- Name: session_storm_entries session_storm_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_storm_entries
    ADD CONSTRAINT session_storm_entries_pkey PRIMARY KEY (id);


--
-- TOC entry 5203 (class 2606 OID 66978)
-- Name: sim_balances sim_balances_owner_type_owner_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sim_balances
    ADD CONSTRAINT sim_balances_owner_type_owner_id_key UNIQUE (owner_type, owner_id);


--
-- TOC entry 5205 (class 2606 OID 66976)
-- Name: sim_balances sim_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sim_balances
    ADD CONSTRAINT sim_balances_pkey PRIMARY KEY (id);


--
-- TOC entry 5168 (class 2606 OID 17193)
-- Name: store_register_state store_register_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store_register_state
    ADD CONSTRAINT store_register_state_pkey PRIMARY KEY (id);


--
-- TOC entry 5099 (class 2606 OID 16839)
-- Name: stores stores_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_name_key UNIQUE (name);


--
-- TOC entry 5101 (class 2606 OID 16837)
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- TOC entry 5106 (class 2606 OID 16859)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5108 (class 2606 OID 16861)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 5152 (class 1259 OID 17293)
-- Name: idx_acc_product; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_acc_product ON public.session_accessory_sales USING btree (product_id);


--
-- TOC entry 5153 (class 1259 OID 17487)
-- Name: idx_acc_sales_customer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_acc_sales_customer ON public.session_accessory_sales USING btree (customer_id);


--
-- TOC entry 5154 (class 1259 OID 17292)
-- Name: idx_acc_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_acc_session ON public.session_accessory_sales USING btree (session_id);


--
-- TOC entry 5155 (class 1259 OID 17294)
-- Name: idx_acc_voided; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_acc_voided ON public.session_accessory_sales USING btree (session_id) WHERE (is_voided = false);


--
-- TOC entry 5177 (class 1259 OID 17303)
-- Name: idx_audit_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_created ON public.audit_logs USING btree (created_at DESC);


--
-- TOC entry 5178 (class 1259 OID 17302)
-- Name: idx_audit_table; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_table ON public.audit_logs USING btree (table_name, record_id);


--
-- TOC entry 5179 (class 1259 OID 17301)
-- Name: idx_audit_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_user ON public.audit_logs USING btree (user_id);


--
-- TOC entry 5192 (class 1259 OID 25995)
-- Name: idx_cashier_advances_cashier_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cashier_advances_cashier_id ON public.cashier_advances USING btree (cashier_id);


--
-- TOC entry 5193 (class 1259 OID 25996)
-- Name: idx_cashier_advances_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cashier_advances_created_at ON public.cashier_advances USING btree (created_at);


--
-- TOC entry 5188 (class 1259 OID 17469)
-- Name: idx_customers_name_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_customers_name_trgm ON public.customers USING gin (((((first_name)::text || ' '::text) || (last_name)::text)) public.gin_trgm_ops);


--
-- TOC entry 5189 (class 1259 OID 17468)
-- Name: idx_customers_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_customers_phone ON public.customers USING btree (phone_number);


--
-- TOC entry 5158 (class 1259 OID 17295)
-- Name: idx_debts_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_debts_session ON public.session_debts USING btree (session_id);


--
-- TOC entry 5159 (class 1259 OID 17296)
-- Name: idx_debts_voided; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_debts_voided ON public.session_debts USING btree (session_id) WHERE (is_voided = false);


--
-- TOC entry 5115 (class 1259 OID 17274)
-- Name: idx_offers_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_offers_active ON public.offers USING btree (is_active) WHERE (is_active = true);


--
-- TOC entry 5116 (class 1259 OID 17441)
-- Name: idx_offers_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_offers_category ON public.offers USING btree (category_id);


--
-- TOC entry 5117 (class 1259 OID 17276)
-- Name: idx_offers_name_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_offers_name_trgm ON public.offers USING gin (name public.gin_trgm_ops);


--
-- TOC entry 5118 (class 1259 OID 17275)
-- Name: idx_offers_sort; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_offers_sort ON public.offers USING btree (sort_order);


--
-- TOC entry 5165 (class 1259 OID 17297)
-- Name: idx_pool_updated; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pool_updated ON public.global_pool_state USING btree (updated_at DESC);


--
-- TOC entry 5125 (class 1259 OID 17278)
-- Name: idx_products_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_active ON public.products USING btree (is_active) WHERE (is_active = true);


--
-- TOC entry 5126 (class 1259 OID 17277)
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_category ON public.products USING btree (category_id);


--
-- TOC entry 5127 (class 1259 OID 17280)
-- Name: idx_products_name_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_name_trgm ON public.products USING gin (name public.gin_trgm_ops);


--
-- TOC entry 5128 (class 1259 OID 17279)
-- Name: idx_products_sort; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_sort ON public.products USING btree (category_id, sort_order);


--
-- TOC entry 5109 (class 1259 OID 17273)
-- Name: idx_refresh_tokens_expires; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_refresh_tokens_expires ON public.refresh_tokens USING btree (expires_at);


--
-- TOC entry 5110 (class 1259 OID 17272)
-- Name: idx_refresh_tokens_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_refresh_tokens_user ON public.refresh_tokens USING btree (user_id);


--
-- TOC entry 5194 (class 1259 OID 26046)
-- Name: idx_register_expenses_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_register_expenses_date ON public.register_expenses USING btree (expense_date);


--
-- TOC entry 5195 (class 1259 OID 26045)
-- Name: idx_register_expenses_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_register_expenses_store_id ON public.register_expenses USING btree (store_id);


--
-- TOC entry 5166 (class 1259 OID 17298)
-- Name: idx_register_store; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_register_store ON public.store_register_state USING btree (store_id, updated_at DESC);


--
-- TOC entry 5171 (class 1259 OID 17299)
-- Name: idx_reports_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reports_date ON public.daily_reports USING btree (report_date DESC);


--
-- TOC entry 5172 (class 1259 OID 17300)
-- Name: idx_reports_store; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reports_store ON public.daily_reports USING btree (store_id);


--
-- TOC entry 5160 (class 1259 OID 26002)
-- Name: idx_session_debts_customer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_session_debts_customer_id ON public.session_debts USING btree (customer_id);


--
-- TOC entry 5135 (class 1259 OID 17281)
-- Name: idx_sessions_cashier; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sessions_cashier ON public.cashier_sessions USING btree (cashier_id);


--
-- TOC entry 5136 (class 1259 OID 17283)
-- Name: idx_sessions_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sessions_date ON public.cashier_sessions USING btree (session_date);


--
-- TOC entry 5137 (class 1259 OID 17284)
-- Name: idx_sessions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sessions_status ON public.cashier_sessions USING btree (status) WHERE (status = 'open'::public.session_status);


--
-- TOC entry 5138 (class 1259 OID 17282)
-- Name: idx_sessions_store; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sessions_store ON public.cashier_sessions USING btree (store_id);


--
-- TOC entry 5141 (class 1259 OID 17476)
-- Name: idx_sim_sales_customer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sim_sales_customer ON public.session_sim_sales USING btree (customer_id);


--
-- TOC entry 5142 (class 1259 OID 17288)
-- Name: idx_sim_sales_offer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sim_sales_offer ON public.session_sim_sales USING btree (offer_id);


--
-- TOC entry 5143 (class 1259 OID 17287)
-- Name: idx_sim_sales_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sim_sales_session ON public.session_sim_sales USING btree (session_id);


--
-- TOC entry 5144 (class 1259 OID 17289)
-- Name: idx_sim_sales_voided; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sim_sales_voided ON public.session_sim_sales USING btree (session_id) WHERE (is_voided = false);


--
-- TOC entry 5147 (class 1259 OID 17493)
-- Name: idx_storm_customer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_storm_customer ON public.session_storm_entries USING btree (customer_id);


--
-- TOC entry 5148 (class 1259 OID 17290)
-- Name: idx_storm_session; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_storm_session ON public.session_storm_entries USING btree (session_id);


--
-- TOC entry 5149 (class 1259 OID 17291)
-- Name: idx_storm_voided; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_storm_voided ON public.session_storm_entries USING btree (session_id) WHERE (is_voided = false);


--
-- TOC entry 5102 (class 1259 OID 17271)
-- Name: idx_users_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_active ON public.users USING btree (is_active) WHERE (is_active = true);


--
-- TOC entry 5103 (class 1259 OID 17270)
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- TOC entry 5104 (class 1259 OID 17269)
-- Name: idx_users_store; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_store ON public.users USING btree (store_id);


--
-- TOC entry 5403 (class 2618 OID 66987)
-- Name: v_session_live_totals _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.v_session_live_totals AS
 SELECT cs.id AS session_id,
    cs.cashier_id,
    u.full_name AS cashier_name,
    cs.store_id,
    s.name AS store_name,
    cs.session_date,
    cs.opening_cash,
    count(ss.id) FILTER (WHERE (ss.is_voided = false)) AS sim_units_sold,
    COALESCE(sum(ss.real_price_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::numeric) AS sim_total_real_price,
    COALESCE(sum(ss.selling_price_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::numeric) AS sim_total_selling_price,
    COALESCE(sum(ss.commission_points_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::bigint) AS sim_total_points,
    COALESCE(sum(ss.commission_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::numeric) AS sim_total_commission,
    COALESCE(sum((((ss.commission_points_snapshot)::numeric + ss.selling_price_snapshot) - ss.real_price_snapshot)) FILTER (WHERE (ss.is_voided = false)), (0)::numeric) AS sim_total_profit,
    COALESCE(sum(se.amount) FILTER (WHERE (se.is_voided = false)), (0)::numeric) AS storm_total,
    COALESCE(sum(sa.price_snapshot) FILTER (WHERE (sa.is_voided = false)), (0)::numeric) AS accessories_total,
    COALESCE(sum(sa.real_price_snapshot) FILTER (WHERE (sa.is_voided = false)), (0)::numeric) AS accessories_total_real_price,
    COALESCE(sum(sa.commission_snapshot) FILTER (WHERE (sa.is_voided = false)), (0)::numeric) AS accessories_total_commission,
    COALESCE(sum((sa.price_snapshot - sa.real_price_snapshot)) FILTER (WHERE (sa.is_voided = false)), (0)::numeric) AS accessories_total_profit,
    COALESCE(sum(sd.amount) FILTER (WHERE (sd.is_voided = false)), (0)::numeric) AS debt_total,
    ((((cs.opening_cash + COALESCE(sum(ss.selling_price_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::numeric)) + COALESCE(sum(se.amount) FILTER (WHERE (se.is_voided = false)), (0)::numeric)) + COALESCE(sum(sa.price_snapshot) FILTER (WHERE (sa.is_voided = false)), (0)::numeric)) - COALESCE(sum(sd.amount) FILTER (WHERE (sd.is_voided = false)), (0)::numeric)) AS expected_register_cash,
    (COALESCE(sum(ss.commission_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::numeric) + COALESCE(sum(sa.commission_snapshot) FILTER (WHERE (sa.is_voided = false)), (0)::numeric)) AS total_cashier_benefit,
    ((COALESCE(sum(ss.loyalty_redeemed_snapshot) FILTER (WHERE (ss.is_voided = false)), (0)::numeric) + COALESCE(sum(se.loyalty_redeemed_snapshot) FILTER (WHERE (se.is_voided = false)), (0)::numeric)) + COALESCE(sum(sa.loyalty_redeemed_snapshot) FILTER (WHERE (sa.is_voided = false)), (0)::numeric)) AS loyalty_points_redeemed,
    ((COALESCE(sum(ss.selling_price_snapshot) FILTER (WHERE ((ss.is_voided = false) AND (ss.customer_id IS NOT NULL))), (0)::numeric) + COALESCE(sum(se.amount) FILTER (WHERE ((se.is_voided = false) AND (se.customer_id IS NOT NULL))), (0)::numeric)) + COALESCE(sum(sa.price_snapshot) FILTER (WHERE ((sa.is_voided = false) AND (sa.customer_id IS NOT NULL))), (0)::numeric)) AS loyalty_driven_revenue
   FROM ((((((public.cashier_sessions cs
     JOIN public.users u ON ((u.id = cs.cashier_id)))
     JOIN public.stores s ON ((s.id = cs.store_id)))
     LEFT JOIN public.session_sim_sales ss ON ((ss.session_id = cs.id)))
     LEFT JOIN public.session_storm_entries se ON ((se.session_id = cs.id)))
     LEFT JOIN public.session_accessory_sales sa ON ((sa.session_id = cs.id)))
     LEFT JOIN public.session_debts sd ON ((sd.session_id = cs.id)))
  GROUP BY cs.id, u.full_name, s.name;


--
-- TOC entry 5253 (class 2620 OID 17470)
-- Name: customers trg_customers_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


--
-- TOC entry 5248 (class 2620 OID 17340)
-- Name: session_accessory_sales trg_guard_acc_sales_closed_session; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_guard_acc_sales_closed_session BEFORE INSERT ON public.session_accessory_sales FOR EACH ROW EXECUTE FUNCTION public.fn_guard_closed_session();


--
-- TOC entry 5249 (class 2620 OID 17341)
-- Name: session_debts trg_guard_debts_closed_session; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_guard_debts_closed_session BEFORE INSERT ON public.session_debts FOR EACH ROW EXECUTE FUNCTION public.fn_guard_closed_session();


--
-- TOC entry 5246 (class 2620 OID 17338)
-- Name: session_sim_sales trg_guard_sim_sales_closed_session; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_guard_sim_sales_closed_session BEFORE INSERT ON public.session_sim_sales FOR EACH ROW EXECUTE FUNCTION public.fn_guard_closed_session();


--
-- TOC entry 5247 (class 2620 OID 17339)
-- Name: session_storm_entries trg_guard_storm_closed_session; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_guard_storm_closed_session BEFORE INSERT ON public.session_storm_entries FOR EACH ROW EXECUTE FUNCTION public.fn_guard_closed_session();


--
-- TOC entry 5244 (class 2620 OID 17329)
-- Name: offers trg_offers_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_offers_updated_at BEFORE UPDATE ON public.offers FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


--
-- TOC entry 5245 (class 2620 OID 17330)
-- Name: products trg_products_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


--
-- TOC entry 5252 (class 2620 OID 58856)
-- Name: audit_logs trg_protect_audit_logs; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_protect_audit_logs BEFORE DELETE OR UPDATE ON public.audit_logs FOR EACH ROW EXECUTE FUNCTION public.fn_protect_audit_logs();


--
-- TOC entry 5250 (class 2620 OID 58854)
-- Name: daily_reports trg_protect_daily_reports_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_protect_daily_reports_delete BEFORE DELETE ON public.daily_reports FOR EACH ROW EXECUTE FUNCTION public.fn_protect_daily_reports();


--
-- TOC entry 5251 (class 2620 OID 58855)
-- Name: daily_reports trg_protect_daily_reports_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_protect_daily_reports_update BEFORE UPDATE ON public.daily_reports FOR EACH ROW EXECUTE FUNCTION public.fn_protect_daily_reports_update();


--
-- TOC entry 5243 (class 2620 OID 17328)
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();


--
-- TOC entry 5231 (class 2606 OID 17264)
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- TOC entry 5234 (class 2606 OID 25980)
-- Name: cashier_advances cashier_advances_cashier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_advances
    ADD CONSTRAINT cashier_advances_cashier_id_fkey FOREIGN KEY (cashier_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5235 (class 2606 OID 25990)
-- Name: cashier_advances cashier_advances_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_advances
    ADD CONSTRAINT cashier_advances_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- TOC entry 5236 (class 2606 OID 42330)
-- Name: cashier_advances cashier_advances_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_advances
    ADD CONSTRAINT cashier_advances_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.cashier_sessions(id) ON DELETE SET NULL;


--
-- TOC entry 5237 (class 2606 OID 25985)
-- Name: cashier_advances cashier_advances_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_advances
    ADD CONSTRAINT cashier_advances_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id);


--
-- TOC entry 5210 (class 2606 OID 16984)
-- Name: cashier_sessions cashier_sessions_cashier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_sessions
    ADD CONSTRAINT cashier_sessions_cashier_id_fkey FOREIGN KEY (cashier_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- TOC entry 5211 (class 2606 OID 16989)
-- Name: cashier_sessions cashier_sessions_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cashier_sessions
    ADD CONSTRAINT cashier_sessions_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE RESTRICT;


--
-- TOC entry 5232 (class 2606 OID 17463)
-- Name: customers customers_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5233 (class 2606 OID 66920)
-- Name: customers customers_referred_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_referred_by_fkey FOREIGN KEY (referred_by) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- TOC entry 5229 (class 2606 OID 17245)
-- Name: daily_reports daily_reports_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- TOC entry 5230 (class 2606 OID 17240)
-- Name: daily_reports daily_reports_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_reports
    ADD CONSTRAINT daily_reports_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE RESTRICT;


--
-- TOC entry 5226 (class 2606 OID 17172)
-- Name: global_pool_state global_pool_state_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_pool_state
    ADD CONSTRAINT global_pool_state_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- TOC entry 5242 (class 2606 OID 66939)
-- Name: loyalty_ledger loyalty_ledger_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loyalty_ledger
    ADD CONSTRAINT loyalty_ledger_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE CASCADE;


--
-- TOC entry 5208 (class 2606 OID 17435)
-- Name: offers offers_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.offer_categories(id) ON DELETE RESTRICT;


--
-- TOC entry 5209 (class 2606 OID 16959)
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.product_categories(id) ON DELETE RESTRICT;


--
-- TOC entry 5207 (class 2606 OID 16886)
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5238 (class 2606 OID 26040)
-- Name: register_expenses register_expenses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.register_expenses
    ADD CONSTRAINT register_expenses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- TOC entry 5239 (class 2606 OID 26025)
-- Name: register_expenses register_expenses_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.register_expenses
    ADD CONSTRAINT register_expenses_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.cashier_sessions(id) ON DELETE SET NULL;


--
-- TOC entry 5240 (class 2606 OID 26030)
-- Name: register_expenses register_expenses_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.register_expenses
    ADD CONSTRAINT register_expenses_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- TOC entry 5241 (class 2606 OID 26035)
-- Name: register_expenses register_expenses_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.register_expenses
    ADD CONSTRAINT register_expenses_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id);


--
-- TOC entry 5219 (class 2606 OID 17481)
-- Name: session_accessory_sales session_accessory_sales_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_accessory_sales
    ADD CONSTRAINT session_accessory_sales_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- TOC entry 5220 (class 2606 OID 17114)
-- Name: session_accessory_sales session_accessory_sales_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_accessory_sales
    ADD CONSTRAINT session_accessory_sales_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE SET NULL;


--
-- TOC entry 5221 (class 2606 OID 17109)
-- Name: session_accessory_sales session_accessory_sales_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_accessory_sales
    ADD CONSTRAINT session_accessory_sales_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.cashier_sessions(id) ON DELETE CASCADE;


--
-- TOC entry 5222 (class 2606 OID 17119)
-- Name: session_accessory_sales session_accessory_sales_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_accessory_sales
    ADD CONSTRAINT session_accessory_sales_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5223 (class 2606 OID 25997)
-- Name: session_debts session_debts_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_debts
    ADD CONSTRAINT session_debts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;


--
-- TOC entry 5224 (class 2606 OID 17141)
-- Name: session_debts session_debts_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_debts
    ADD CONSTRAINT session_debts_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.cashier_sessions(id) ON DELETE CASCADE;


--
-- TOC entry 5225 (class 2606 OID 17146)
-- Name: session_debts session_debts_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_debts
    ADD CONSTRAINT session_debts_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5212 (class 2606 OID 17471)
-- Name: session_sim_sales session_sim_sales_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_sim_sales
    ADD CONSTRAINT session_sim_sales_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- TOC entry 5213 (class 2606 OID 17052)
-- Name: session_sim_sales session_sim_sales_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_sim_sales
    ADD CONSTRAINT session_sim_sales_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id) ON DELETE RESTRICT;


--
-- TOC entry 5214 (class 2606 OID 17047)
-- Name: session_sim_sales session_sim_sales_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_sim_sales
    ADD CONSTRAINT session_sim_sales_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.cashier_sessions(id) ON DELETE CASCADE;


--
-- TOC entry 5215 (class 2606 OID 17057)
-- Name: session_sim_sales session_sim_sales_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_sim_sales
    ADD CONSTRAINT session_sim_sales_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5216 (class 2606 OID 17488)
-- Name: session_storm_entries session_storm_entries_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_storm_entries
    ADD CONSTRAINT session_storm_entries_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE SET NULL;


--
-- TOC entry 5217 (class 2606 OID 17079)
-- Name: session_storm_entries session_storm_entries_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_storm_entries
    ADD CONSTRAINT session_storm_entries_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.cashier_sessions(id) ON DELETE CASCADE;


--
-- TOC entry 5218 (class 2606 OID 17084)
-- Name: session_storm_entries session_storm_entries_voided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_storm_entries
    ADD CONSTRAINT session_storm_entries_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- TOC entry 5227 (class 2606 OID 17194)
-- Name: store_register_state store_register_state_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store_register_state
    ADD CONSTRAINT store_register_state_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- TOC entry 5228 (class 2606 OID 17199)
-- Name: store_register_state store_register_state_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.store_register_state
    ADD CONSTRAINT store_register_state_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- TOC entry 5206 (class 2606 OID 16862)
-- Name: users users_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE RESTRICT;


--
-- TOC entry 5405 (class 0 OID 16965)
-- Dependencies: 234
-- Name: cashier_sessions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.cashier_sessions ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 5413 (class 3256 OID 17345)
-- Name: session_accessory_sales policy_acc_sales_isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY policy_acc_sales_isolation ON public.session_accessory_sales USING (((current_setting('app.current_user_role'::text, true) = 'admin'::text) OR (EXISTS ( SELECT 1
   FROM public.cashier_sessions cs
  WHERE ((cs.id = session_accessory_sales.session_id) AND (cs.cashier_id = (current_setting('app.current_user_id'::text, true))::integer))))));


--
-- TOC entry 5414 (class 3256 OID 17346)
-- Name: session_debts policy_debts_isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY policy_debts_isolation ON public.session_debts USING (((current_setting('app.current_user_role'::text, true) = 'admin'::text) OR (EXISTS ( SELECT 1
   FROM public.cashier_sessions cs
  WHERE ((cs.id = session_debts.session_id) AND (cs.cashier_id = (current_setting('app.current_user_id'::text, true))::integer))))));


--
-- TOC entry 5410 (class 3256 OID 17342)
-- Name: cashier_sessions policy_sessions_isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY policy_sessions_isolation ON public.cashier_sessions USING (((current_setting('app.current_user_role'::text, true) = 'admin'::text) OR (cashier_id = (current_setting('app.current_user_id'::text, true))::integer)));


--
-- TOC entry 5411 (class 3256 OID 17343)
-- Name: session_sim_sales policy_sim_sales_isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY policy_sim_sales_isolation ON public.session_sim_sales USING (((current_setting('app.current_user_role'::text, true) = 'admin'::text) OR (EXISTS ( SELECT 1
   FROM public.cashier_sessions cs
  WHERE ((cs.id = session_sim_sales.session_id) AND (cs.cashier_id = (current_setting('app.current_user_id'::text, true))::integer))))));


--
-- TOC entry 5412 (class 3256 OID 17344)
-- Name: session_storm_entries policy_storm_isolation; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY policy_storm_isolation ON public.session_storm_entries USING (((current_setting('app.current_user_role'::text, true) = 'admin'::text) OR (EXISTS ( SELECT 1
   FROM public.cashier_sessions cs
  WHERE ((cs.id = session_storm_entries.session_id) AND (cs.cashier_id = (current_setting('app.current_user_id'::text, true))::integer))))));


--
-- TOC entry 5408 (class 0 OID 17090)
-- Dependencies: 240
-- Name: session_accessory_sales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.session_accessory_sales ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 5409 (class 0 OID 17125)
-- Dependencies: 242
-- Name: session_debts; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.session_debts ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 5406 (class 0 OID 17027)
-- Dependencies: 236
-- Name: session_sim_sales; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.session_sim_sales ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 5407 (class 0 OID 17063)
-- Dependencies: 238
-- Name: session_storm_entries; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.session_storm_entries ENABLE ROW LEVEL SECURITY;

-- Completed on 2026-08-31 19:24:32

--
-- PostgreSQL database dump complete
--

\unrestrict ezGtdETa5yIu6PbsAy25KUOkqiMNeuuCFIZ9Ipn9XasbueSGxHigh5lYWlDtjfQ

-- Completed on 2026-08-31 19:24:32

--
-- PostgreSQL database cluster dump complete
--

