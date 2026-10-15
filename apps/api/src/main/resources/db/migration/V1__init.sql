-- V1__init.sql
create table users (
                       id            bigserial primary key,
                       email         text        not null,
                       password_hash text        not null,          -- BCrypt
                       display_name  text,
                       created_at    timestamptz not null default now()
);
create unique index ux_users_email on users (lower(email));

create table user_settings (
                               user_id             bigint primary key references users(id) on delete cascade,
                               starting_savings    numeric(14,2) not null default 0,
                               monthly_saving_goal numeric(14,2) not null default 0
);

create table categories (
                            id         bigserial primary key,
                            user_id    bigint not null references users(id) on delete cascade,
                            name       text   not null,
                            kind       text   not null check (kind in ('INCOME','EXPENSE')),
                            sort_order int    not null default 0,
                            unique (user_id, name)
);

-- курс НБУ на дату однаковий для всіх, тому таблиця спільна і без user_id
create table exchange_rates (
                                currency   char(3)       not null,
                                rate_date  date          not null,
                                rate       numeric(12,6) not null,
                                fetched_at timestamptz   not null default now(),
                                primary key (currency, rate_date)
);

create table planned_expenses (
                                  id           bigserial primary key,
                                  user_id      bigint        not null references users(id) on delete cascade,
                                  name         text          not null,
                                  category_id  bigint        references categories(id),
                                  amount       numeric(14,2) not null check (amount > 0),
                                  currency     char(3)       not null default 'UAH',
                                  frequency    text          not null check (frequency in ('MONTHLY','YEARLY')),
                                  day_of_month smallint      check (day_of_month between 1 and 31),
                                  month        smallint      check (month between 1 and 12), -- лише для YEARLY
  active       boolean       not null default true,
  created_at   timestamptz   not null default now()
);
create index ix_planned_user on planned_expenses (user_id);

create table transactions (
                              id                 bigserial primary key,
                              user_id            bigint        not null references users(id) on delete cascade,
                              kind               text          not null check (kind in ('INCOME','EXPENSE','SAVING')),
                              source             text          check (source in ('PLANNED','DAILY')), -- лише для EXPENSE
                              op_date            date          not null,
                              amount             numeric(14,2) not null check (amount > 0),
                              currency           char(3)       not null,
                              rate               numeric(12,6) not null default 1,
                              rate_source        text          not null default 'NONE' check (rate_source in ('NBU','MANUAL','NONE')),
                              amount_uah         numeric(14,2) not null,
                              category_id        bigint        references categories(id),
                              planned_expense_id bigint        references planned_expenses(id),
                              period             char(7),      -- '2026-10', місяць, за який оплачено очікувану витрату
                              note               text,
                              created_at         timestamptz   not null default now(),
                              updated_at         timestamptz   not null default now(),
                              check (kind = 'EXPENSE' or source is null),
                              check ((planned_expense_id is null) = (period is null))
);

-- одна оплата очікуваної витрати за місяць
create unique index ux_tx_planned_period on transactions (planned_expense_id, period)
    where planned_expense_id is not null;
create index ix_tx_user_date on transactions (user_id, op_date);