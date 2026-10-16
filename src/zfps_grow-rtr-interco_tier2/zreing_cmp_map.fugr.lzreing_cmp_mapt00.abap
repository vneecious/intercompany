*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_CMP_MAP_V................................*
TABLES: ZREING_CMP_MAP_V, *ZREING_CMP_MAP_V. "view work areas
CONTROLS: TCTRL_ZREING_CMP_MAP_V
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZREING_CMP_MAP_V. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZREING_CMP_MAP_V.
* Table for entries selected to show on screen
DATA: BEGIN OF ZREING_CMP_MAP_V_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZREING_CMP_MAP_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_CMP_MAP_V_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZREING_CMP_MAP_V_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZREING_CMP_MAP_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_CMP_MAP_V_TOTAL.

*.........table declarations:.................................*
TABLES: ZREING_CMP_MAP_C               .
