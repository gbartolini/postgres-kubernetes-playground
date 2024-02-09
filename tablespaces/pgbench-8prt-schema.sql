\c pgbench
SET ROLE app;

CREATE TABLE public.pgbench_accounts (
    aid bigint NOT NULL,
    bid integer,
    abalance integer,
    filler character(84)
)
PARTITION BY HASH (aid);

CREATE TABLE public.pgbench_accounts_1 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_2 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_3 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_4 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_5 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_6 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_7 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_accounts_8 (
    LIKE public.pgbench_accounts
);

CREATE TABLE public.pgbench_branches (
    bid integer NOT NULL,
    bbalance integer,
    filler character(88)
);

CREATE TABLE public.pgbench_history (
    tid int,
    bid int,
    aid bigint,
    delta int,
    mtime timestamp,
    filler char(22)
)
PARTITION BY HASH (aid);

CREATE TABLE public.pgbench_history_1 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_2 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_3 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_4 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_5 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_6 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_7 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_history_8 (
    LIKE public.pgbench_history
);

CREATE TABLE public.pgbench_tellers (
    tid integer NOT NULL,
    bid integer,
    tbalance integer,
    filler character(84)
);

ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_1 FOR VALUES WITH (modulus 8, remainder 0);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_2 FOR VALUES WITH (modulus 8, remainder 1);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_3 FOR VALUES WITH (modulus 8, remainder 2);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_4 FOR VALUES WITH (modulus 8, remainder 3);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_5 FOR VALUES WITH (modulus 8, remainder 4);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_6 FOR VALUES WITH (modulus 8, remainder 5);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_7 FOR VALUES WITH (modulus 8, remainder 6);
ALTER TABLE ONLY public.pgbench_accounts ATTACH PARTITION public.pgbench_accounts_8 FOR VALUES WITH (modulus 8, remainder 7);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_1 FOR VALUES WITH (modulus 8, remainder 0);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_2 FOR VALUES WITH (modulus 8, remainder 1);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_3 FOR VALUES WITH (modulus 8, remainder 2);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_4 FOR VALUES WITH (modulus 8, remainder 3);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_5 FOR VALUES WITH (modulus 8, remainder 4);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_6 FOR VALUES WITH (modulus 8, remainder 5);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_7 FOR VALUES WITH (modulus 8, remainder 6);
ALTER TABLE ONLY public.pgbench_history ATTACH PARTITION public.pgbench_history_8 FOR VALUES WITH (modulus 8, remainder 7);

ALTER TABLE ONLY public.pgbench_accounts
    ADD CONSTRAINT pgbench_accounts_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_1
    ADD CONSTRAINT pgbench_accounts_1_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_2
    ADD CONSTRAINT pgbench_accounts_2_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_3
    ADD CONSTRAINT pgbench_accounts_3_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_4
    ADD CONSTRAINT pgbench_accounts_4_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_5
    ADD CONSTRAINT pgbench_accounts_5_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_6
    ADD CONSTRAINT pgbench_accounts_6_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_7
    ADD CONSTRAINT pgbench_accounts_7_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_accounts_8
    ADD CONSTRAINT pgbench_accounts_8_pkey PRIMARY KEY (aid);
ALTER TABLE ONLY public.pgbench_branches
    ADD CONSTRAINT pgbench_branches_pkey PRIMARY KEY (bid);
ALTER TABLE ONLY public.pgbench_tellers
    ADD CONSTRAINT pgbench_tellers_pkey PRIMARY KEY (tid);

ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_1_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_2_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_3_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_4_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_5_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_6_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_7_pkey;
ALTER INDEX public.pgbench_accounts_pkey ATTACH PARTITION public.pgbench_accounts_8_pkey;
