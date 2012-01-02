DROP SCHEMA     timesheet CASCADE;
CREATE SCHEMA   timesheet;

CREATE TABLE    timesheet.kind
  ( name        text PRIMARY KEY );
INSERT INTO timesheet.kind VALUES ( '' );

CREATE TABLE    timesheet.client
  ( name        text PRIMARY KEY,
    remark      text DEFAULT '' NOT NULL );

CREATE TABLE    timesheet.clock
  ( client      text REFERENCES timesheet.client(name) NOT NULL,
    clockin     timestamp with time zone NOT NULL,
    clockout    timestamp with time zone NOT NULL,
 -- tz          text REFERENCES pg_catalog.pg_timezone_names(name) NOT NULL,
    tz          text NOT NULL,
    kind        text REFERENCES timesheet.kind(name) DEFAULT '' NOT NULL,
    remark      text DEFAULT '' NOT NULL );
COMMENT ON TABLE timesheet.clock IS 'Hours worked for all clients.' ;

CREATE VIEW     timesheet.hours AS
     SELECT     client,
                div(EXTRACT(EPOCH FROM clockout - clockin) :: numeric, 60)
                 AS minutes,
                clockin, clockout, tz, kind, remark
       FROM     timesheet.clock ;

