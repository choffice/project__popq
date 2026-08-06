ALTER TABLE store_members
    ADD COLUMN display_order INT NOT NULL DEFAULT 0;

UPDATE store_members
SET display_order = store_member_id;
