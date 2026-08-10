ALTER TABLE stores
    ADD COLUMN operation_start_date DATE NULL AFTER close_time,
    ADD COLUMN operation_end_date DATE NULL AFTER operation_start_date;
