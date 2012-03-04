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
    remark      text DEFAULT '' NOT NULL,
    CONSTRAINT non_negative_hours CHECK (clockin <= clockout) );
COMMENT ON TABLE timesheet.clock IS 'Hours worked for all clients.' ;

CREATE VIEW     timesheet.hours AS
     SELECT     client,
                (clockout - clockin) AS interval,
                EXTRACT(EPOCH FROM (clockout - clockin)) AS seconds,
                clockin, clockout, tz, kind, remark
       FROM     timesheet.clock ;

CREATE OR REPLACE FUNCTION timesheet.hours_and_minutes(double precision)
RETURNS text AS $$
DECLARE
  minutes integer;
BEGIN
  minutes := $1 / 60;
  RETURN to_char(minutes / 60, 'FM00') || 'h, '
      || to_char(minutes % 60, 'FM00') || 'm';
END
$$ LANGUAGE plpgsql STRICT;

-- California overtime rules:
--  * In a given day, the first 8 hours are straight-time, the next 4 are
--    time-and-a-half and the remaining hours are double time.
--  * Any hours in excess of 40 a week, not accounted for by daily over time,
--    must be paid at time-and-a-half.
--  * And then there is the 7th day time-and-a-half/double-time rule. On the
--    7th consecutive day of work, the first 8 hours are time-and-a-half and
--    any remaining hours are double-time.
-- From: http://www.management-advantage.com/products/overtime-exempt.html


CREATE VIEW     timesheet.summary AS
     SELECT     *,
                to_char(clockin AT TIME ZONE tz, 'Mon DD HH24:MI') AS i,
                to_char(clockout AT TIME ZONE tz, 'Mon DD HH24:MI') AS o,
                timesheet.hours_and_minutes(seconds) AS hours_and_minutes
       FROM     timesheet.hours;

CREATE VIEW     timesheet.lines AS
     SELECT     *,
                i||' / '||o||' -- '||hours_and_minutes||' -- '||remark AS
                  summary
       FROM     timesheet.summary ;

CREATE OR REPLACE FUNCTION timesheet.days_of_week
  (start_date timestamp with time zone, weeks integer) -- TODO: add TZ
RETURNS TABLE(day_num integer, day_start timestamp with time zone,
                               day_end   timestamp with time zone) AS $$
BEGIN
  day_start := start_date;
  FOR d IN 0..(weeks * 7) LOOP
    day_num := d;
    day_end := day_start + interval 'P1D';
    RETURN NEXT;
    day_start := day_end;
  END LOOP;
  RETURN;
END
$$ LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION timesheet.interval_intersect
  (a0 timestamp with time zone, a1 timestamp with time zone,
   b0 timestamp with time zone, b1 timestamp with time zone)
RETURNS interval AS $$
DECLARE
  i    interval;
  zero interval := interval '0';
  a0_  timestamp with time zone; -- The nearest point on b to a0
  a1_  timestamp with time zone; -- The nearest point on b to a1
BEGIN
  CASE WHEN a0 < b0 THEN a0_ := b0;
       WHEN a0 > b1 THEN a0_ := b1;
                    ELSE a0_ := a0;
  END CASE;
  CASE WHEN a1 < b0 THEN a1_ := b0;
       WHEN a1 > b1 THEN a1_ := b1;
                    ELSE a1_ := a1;
  END CASE;
  -- Vector insight: The vector from a0 to a0_ on b, plus the interval vector
  -- projected on to b, plus the vector from a1_ to a1, is equal to a.
  i :=  (a1 - a0) - (a0_ - a0) - (a1 - a1_);
  IF i < zero THEN RETURN zero;
              ELSE RETURN i;
  END IF;
END
$$ LANGUAGE plpgsql STRICT;

