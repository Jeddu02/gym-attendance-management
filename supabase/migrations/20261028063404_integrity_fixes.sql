
-- Integrity repair: link payment allocations to walk-in requests.
-- Draft until tested against PostgreSQL.

begin;

alter table private.payment_allocations
    add constraint payment_allocations_walkin_request_fk
    foreign key (walkin_request_id)
    references private.walkin_requests(id)
    on delete restrict;

commit;
