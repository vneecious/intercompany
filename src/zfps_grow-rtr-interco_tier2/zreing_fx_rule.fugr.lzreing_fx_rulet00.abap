*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_FX_RULE_V................................*
TABLES: ZREING_FX_RULE_V, *ZREING_FX_RULE_V. "view work areas
CONTROLS: TCTRL_ZREING_FX_RULE_V
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZREING_FX_RULE_V. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZREING_FX_RULE_V.
* Table for entries selected to show on screen
DATA: BEGIN OF ZREING_FX_RULE_V_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZREING_FX_RULE_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_FX_RULE_V_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZREING_FX_RULE_V_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZREING_FX_RULE_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_FX_RULE_V_TOTAL.

*.........table declarations:.................................*
TABLES: ZREING_FX_RULE_A               .
