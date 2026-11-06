
-- Prevent overlapping dated membership purchase periods.
-- Draft only: requires PostgreSQL validation before deployment.

begin;

create extension if not exists btree_gist with schema extensions;

alter table private.membership_purchases
    add constraint membership_purchases_no_overlapping_periods
    exclude using gist (
        member_id extensions.gist_uuid_ops with =,
        daterange(activation_date, expiry_date, '[]') with &&
    )
    where (
        activation_date is not null
        and expiry_date is not null
    );

commit;
