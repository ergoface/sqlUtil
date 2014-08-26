ALTER FUNCTION CIntToChar(@intVal BIGINT, @intLen Int) RETURNS nvarchar(20)
AS

/**************************************************************************************
* Description: Converts and Int/BigInt to a char string with leading zeros
* Author: Dave Bennett (from StackOverflow source)
* Created: 10/25/2012
* Last Updated: 10/25/2012 
* Relies on: N/A
* Modifies: N/A
* Parameters: intVal --> Integer to be converted
*             intLen --> Total number of characters to be returned
*  BIGINT = 2^63-1 (9,223,372,036,854,775,807) Max size number
* Example: Select dbo.CIntToChar(5,4) --> 0005 
***************************************************************************************/
BEGIN
    IF @intlen > 20
       SET @intlen = 20

    RETURN REPLICATE('0',@intLen-LEN(RTRIM(CONVERT(nvarchar(20),@intVal)))) 
        + CONVERT(nvarchar(20),@intVal)

END