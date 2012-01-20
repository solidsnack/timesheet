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
                (clockout - clockin) AS interval,
                clockin, clockout, tz, kind, remark
       FROM     timesheet.clock ;

CREATE VIEW     timesheet.minutes AS
     SELECT     client,
                (EXTRACT(EPOCH FROM interval) / 60)::int AS minutes,
                clockin, clockout, tz, kind, remark
       FROM     timesheet.hours ;

CREATE VIEW     timesheet.summary AS
     SELECT     client,
                clockin, clockout,
                minutes,
                to_char(clockin AT TIME ZONE tz, 'Mon DD HH24:MI') AS i,
                to_char(clockout AT TIME ZONE tz, 'Mon DD HH24:MI') AS o,
                tz,
                to_char(minutes / 60, 'FM00') || 'h, ' ||
                to_char(minutes % 60, 'FM00') || 'm'   AS t,
                kind, remark
       FROM     timesheet.minutes ;

CREATE VIEW     timesheet.lines AS
     SELECT     *,
                i||' / '||o||' -- '||t||' -- '||remark AS
                  summary
       FROM     timesheet.summary ;


