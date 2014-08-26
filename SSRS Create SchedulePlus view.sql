/* Create Human readable schedule times on top of the normal fields from the Schedule table */
 
 Create VIEW SchedulePlus
 AS
 
 WITH EnhancedSched
        AS (
             SELECT
               * ,
               CASE WHEN DaysOfWeek & 1 <> 0 THEN 'Sun, '
                    ELSE ''
               END + CASE WHEN DaysOfWeek & 2 <> 0 THEN 'Mon, '
                          ELSE ''
                     END + CASE WHEN DaysOfWeek & 4 <> 0 THEN 'Tue, '
                                ELSE ''
                           END + CASE WHEN DaysOfWeek & 8 <> 0 THEN 'Wed, '
                                      ELSE ''
                                 END
               + CASE WHEN DaysOfWeek & 16 <> 0 THEN 'Thu, '
                      ELSE ''
                 END + CASE WHEN DaysOfWeek & 32 <> 0 THEN 'Fri, '
                            ELSE ''
                       END + CASE WHEN DaysOfWeek & 64 <> 0 THEN 'Sat, '
                                  ELSE ''
                             END AS DaysOfWeekString ,
               CASE WHEN DaysOfMonth & 1 <> 0 THEN '1,'
                    ELSE ''
               END + CASE WHEN DaysOfMonth & 2 <> 0 THEN '2,'
                          ELSE ''
                     END + CASE WHEN DaysOfMonth & 4 <> 0 THEN '3,'
                                ELSE ''
                           END + CASE WHEN DaysOfMonth & 8 <> 0 THEN '4,'
                                      ELSE ''
                                 END
               + CASE WHEN DaysOfMonth & 16 <> 0 THEN '5,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 32 <> 0 THEN '6,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 64 <> 0 THEN '7,'
                                  ELSE ''
                             END + CASE WHEN DaysOfMonth & 128 <> 0 THEN '8,'
                                        ELSE ''
                                   END
               + CASE WHEN DaysOfMonth & 256 <> 0 THEN '9,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 512 <> 0 THEN '10,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 1024 <> 0 THEN '11,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 2048 <> 0 THEN '12,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 4096 <> 0 THEN '13,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 8192 <> 0 THEN '14,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 16384 <> 0 THEN '15,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 32768 <> 0 THEN '16,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 65536 <> 0 THEN '17,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 131072 <> 0 THEN '18,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 262144 <> 0 THEN '19,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 524288 <> 0 THEN '20,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 1048576 <> 0 THEN '21,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 2097152 <> 0 THEN '22,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 4194304 <> 0 THEN '23,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 8388608 <> 0 THEN '24,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 16777216 <> 0 THEN '25,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 33554432 <> 0 THEN '26,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 67108864 <> 0 THEN '27,'
                      ELSE ''
                 END + CASE WHEN DaysOfMonth & 134217728 <> 0 THEN '28,'
                            ELSE ''
                       END + CASE WHEN DaysOfMonth & 268435456 <> 0 THEN '29,'
                                  ELSE ''
                             END
               + CASE WHEN DaysOfMonth & 536870912 <> 0 THEN '30,'
                      ELSE ''
                 END AS DaysOfMonthString ,
               CASE WHEN Month = 4095 THEN 'every month, '
                    ELSE CASE WHEN Month & 1 <> 0 THEN 'Jan, '
                              ELSE ''
                         END + CASE WHEN Month & 2 <> 0 THEN 'Feb, '
                                    ELSE ''
                               END + CASE WHEN Month & 4 <> 0 THEN 'Mar, '
                                          ELSE ''
                                     END
                         + CASE WHEN Month & 8 <> 0 THEN 'Apr, '
                                ELSE ''
                           END + CASE WHEN Month & 16 <> 0 THEN 'May, '
                                      ELSE ''
                                 END + CASE WHEN Month & 32 <> 0 THEN 'Jun, '
                                            ELSE ''
                                       END
                         + CASE WHEN Month & 64 <> 0 THEN 'Jul, '
                                ELSE ''
                           END + CASE WHEN Month & 128 <> 0 THEN 'Aug, '
                                      ELSE ''
                                 END + CASE WHEN Month & 256 <> 0 THEN 'Sep, '
                                            ELSE ''
                                       END
                         + CASE WHEN Month & 512 <> 0 THEN 'Oct, '
                                ELSE ''
                           END + CASE WHEN Month & 1024 <> 0 THEN 'Nov, '
                                      ELSE ''
                                 END
                         + CASE WHEN Month & 2048 <> 0 THEN 'Dec, '
                                ELSE ''
                           END
               END AS MonthString ,
               CASE MonthlyWeek
                 WHEN 1 THEN 'first'
                 WHEN 2 THEN 'second'
                 WHEN 3 THEN 'third'
                 WHEN 4 THEN 'fourth'
                 WHEN 5 THEN 'last'
               END AS MonthlyWeekString ,
               ' starting ' + CONVERT (VARCHAR, StartDate, 101)
               + CASE WHEN EndDate IS NOT NULL
                      THEN ' and ending ' + CONVERT (VARCHAR, EndDate, 101)
                      ELSE ''
                 END AS StartEndString ,
               CONVERT(VARCHAR, DATEPART(hour, StartDate) % 12) + ':'
               + CASE WHEN DATEPART(minute, StartDate) < 10
                      THEN '0' + CONVERT(VARCHAR(2), DATEPART(minute,
                                                              StartDate))
                      ELSE CONVERT(VARCHAR(2), DATEPART(minute, StartDate))
                 END + CASE WHEN DATEPART(hour, StartDate) >= 12 THEN ' PM'
                            ELSE ' AM'
                       END AS StartTime
             FROM
               Schedule
           )
   SELECT
      *, -- spec what you need.
      CASE WHEN RecurrenceType = 1
           THEN 'At ' + StartTime + ' on ' + CONVERT(VARCHAR, StartDate, 101)
           WHEN RecurrenceType = 2
           THEN 'Every ' + CONVERT(VARCHAR, ( MinutesInterval / 60 ))
                + ' hour(s) and ' + CONVERT(VARCHAR, ( MinutesInterval % 60 ))
                + ' minute(s), ' + 'starting ' + CONVERT (VARCHAR, StartDate, 101)
                + ' at ' + SUBSTRING(CONVERT(VARCHAR, StartDate, 8), 0, 6)
                + ' ' + SUBSTRING(CONVERT(VARCHAR, StartDate, 109), 25, 2)
                + CASE WHEN EndDate IS NOT NULL
                       THEN ' and ending ' + CONVERT (VARCHAR, EndDate, 101)
                       ELSE ''
                  END
           WHEN RecurrenceType = 3
           THEN 'At ' + StartTime + ' every ' + CASE DaysInterval
                                                  WHEN 1 THEN 'day, '
                                                  ELSE CONVERT(VARCHAR, DaysInterval)
                                                       + ' days, '
                                                END + StartEndString
           WHEN RecurrenceType = 4
           THEN 'At ' + StartTime + ' every '
                + CASE WHEN LEN(DaysOfWeekString) > 1
                       THEN LEFT(DaysOfWeekString, LEN(DaysOfWeekString) - 1)
                       ELSE ''
                  END + ' of every '
                + CASE WHEN WeeksInterval = 1 THEN ' week,'
                       ELSE CONVERT(VARCHAR, WeeksInterval) + ' weeks,'
                  END + StartEndString
           WHEN RecurrenceType = 5
           THEN 'At ' + StartTime + ' on day(s) '
                + CASE WHEN LEN(DaysOfMonthString) > 1
                       THEN LEFT(DaysOfMonthString, LEN(DaysOfMonthString) - 1)
                       ELSE ''
                  END + ' of ' + MonthString + StartEndString
           WHEN RecurrenceType = 6
           THEN 'At ' + StartTime + ' on the ' + MonthlyWeekString + ' '
                + CASE WHEN LEN(DaysOfWeekString) > 1
                       THEN LEFT(DaysOfWeekString, LEN(DaysOfWeekString) - 1)
                       ELSE ''
                  END + ' of ' + MonthString + StartEndString
           ELSE 'At ' + SUBSTRING(CONVERT(VARCHAR, StartDate, 8), 0, 6) + ' '
                + SUBSTRING(CONVERT(VARCHAR, StartDate, 109), 25, 2)
                + StartEndString
      END AS HumanFriendly
   FROM
      EnhancedSched
go	      