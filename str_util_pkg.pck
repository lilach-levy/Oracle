CREATE OR REPLACE PACKAGE STR_UTIL_PKG is

  --------------------------------------------------------------
  -- Function: is_number
  --
  -- Description: Check if string is a number.
  --------------------------------------------------------------
  FUNCTION is_number(p_str VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------
  -- Function: is_numeric
  --
  -- Description: Check if string holds a numeric value.
  --------------------------------------------------------------
  FUNCTION is_numeric(p_str VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------
  -- Function: is_date
  --
  -- Description: Check if string holds a date value.
  --------------------------------------------------------------
  FUNCTION is_date(p_str    VARCHAR2
                  ,p_format VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  --------------------------------------------------------------
  -- Function: is_email
  --
  -- Description: Check if string holds a valid email value.
  --------------------------------------------------------------
  FUNCTION is_email(p_str VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------
  -- Function: remove_duplicate
  --
  -- Description: Return the string without duplicated characters.
  --------------------------------------------------------------
  FUNCTION remove_duplicate(p_str VARCHAR2) RETURN VARCHAR2;

  --------------------------------------------------------------
  -- Function: get_digits
  --
  -- Description: Get the nth number from the string.
  --------------------------------------------------------------
  FUNCTION get_digits(p_str VARCHAR2
                     ,p_nth NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------
  -- Function: get_num_of_shows
  --
  -- Description: Get the number of the text pattern shows.
  -------------------------------------------------------------
  FUNCTION get_num_of_shows(p_str      VARCHAR2
                           ,p_sub_str  VARCHAR2) RETURN NUMBER;

END STR_UTIL_PKG;
/
CREATE OR REPLACE PACKAGE BODY STR_UTIL_PKG IS

--------------------------------------------------------------
-- Function: is_number
--------------------------------------------------------------
FUNCTION is_number(p_str VARCHAR2)
RETURN VARCHAR2
IS

   l_num NUMBER;

BEGIN

  l_num := TO_NUMBER(p_str);

  RETURN 'Y';

EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END is_number;

--------------------------------------------------------------
-- Function: is_numeric
--------------------------------------------------------------
FUNCTION is_numeric(p_str VARCHAR2)
RETURN VARCHAR2
IS

   l_count NUMBER;

BEGIN

   SELECT COUNT(*)
     INTO l_count
     FROM dual
    WHERE REGEXP_LIKE(p_str
                     ,'^( *)(\+|-)?((\d*[.]?\d+)|(\d+[.]?\d*)){1}(e(\+|-)?\d+)?(f|d)?$'
                     ,'i');

   IF l_count = 1
   THEN
      RETURN 'Y';
   ELSE
      RETURN 'N';
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END is_numeric;

--------------------------------------------------------------
-- Function: is_date
--------------------------------------------------------------
FUNCTION is_date(p_str    VARCHAR2
                ,p_format VARCHAR2 DEFAULT NULL)
RETURN VARCHAR2
IS

   l_date   DATE;
   l_format VARCHAR2(50) := p_format;

BEGIN

  IF l_format IS NULL
  THEN

    SELECT p.property_value
      INTO l_format
      FROM database_properties p
     WHERE p.property_name = 'NLS_DATE_FORMAT';

  END IF;

  l_date := TO_DATE(p_str, l_format);

  RETURN 'Y';

EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END is_date;

--------------------------------------------------------------
-- Function: is_email
--------------------------------------------------------------
FUNCTION is_email(p_str VARCHAR2)
RETURN VARCHAR2
IS

   l_count NUMBER;

BEGIN

   SELECT COUNT(*)
     INTO l_count
     FROM dual
    WHERE REGEXP_LIKE(p_str
                     ,'\w+@\w+(\.\w{3})'
                     ,'i');

   IF l_count = 1
   THEN
      RETURN 'Y';
   ELSE
      RETURN 'N';
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END is_email;

--------------------------------------------------------------
-- Function: remove_duplicate
--------------------------------------------------------------
FUNCTION remove_duplicate(p_str VARCHAR2)
RETURN VARCHAR2
IS

   l_without_duplicate VARCHAR2(4000);

BEGIN

   SELECT REGEXP_REPLACE(p_str, '(\w+) \1', '\1', 1, 0, 'i')
   INTO   l_without_duplicate
   FROM   dual;

   RETURN l_without_duplicate;

EXCEPTION
   WHEN OTHERS THEN
      RETURN NULL;
END remove_duplicate;

--------------------------------------------------------------
-- Function: get_digits
--------------------------------------------------------------
FUNCTION get_digits(p_str VARCHAR2
                   ,p_nth NUMBER)
RETURN VARCHAR2
IS

   l_out_number VARCHAR2(4000);
   l_nth        NUMBER := p_nth;

BEGIN

   SELECT REGEXP_SUBSTR(p_str, '([[:digit:]])+', 1, l_nth)
     INTO l_out_number
     FROM dual;

   RETURN l_out_number;

EXCEPTION
  WHEN OTHERS THEN
      RETURN NULL;
END get_digits;

--------------------------------------------------------------
-- Function: get_num_of_shows
--------------------------------------------------------------
FUNCTION get_num_of_shows(p_str      VARCHAR2
                         ,p_sub_str  VARCHAR2)
RETURN NUMBER
IS

   l_out_num  NUMBER;

BEGIN

  SELECT MAX(LEVEL)
    INTO l_out_num
    FROM dual
  CONNECT BY REGEXP_SUBSTR(p_str, p_sub_str, 1, LEVEL, 'i') IS NOT NULL;

   RETURN l_out_num;

EXCEPTION
   WHEN OTHERS THEN
      RETURN 0;
END get_num_of_shows;

END STR_UTIL_PKG;
/
