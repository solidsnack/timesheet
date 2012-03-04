WITH days AS (SELECT * FROM timesheet.days_of_week('2012-02-18 US/Pacific', 2)),
     overlapped AS (SELECT days.day_num AS num, days.day_start AS day,
                           timesheet.interval_intersect
                             (clockin, clockout, day_start, day_end)
                             AS overlapping
                      FROM days, timesheet.hours WHERE kind = ''),
     days_and_seconds AS (SELECT num, day, SUM(EXTRACT(EPOCH FROM overlapping))
                            FROM overlapped WHERE overlapping > interval '0'
                                            GROUP BY num, day ORDER BY day)
SELECT to_char(day, 'YYYY-MM-DD') AS pacific_day, timesheet.hours_and_minutes(sum) AS time FROM days_and_seconds ORDER BY pacific_day;
