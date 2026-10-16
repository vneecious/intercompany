*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_DOCTP_C_V................................*
TABLES: ZREING_DOCTP_C_V, *ZREING_DOCTP_C_V. "view work areas
CONTROLS: TCTRL_ZREING_DOCTP_C_V
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZREING_DOCTP_C_V. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZREING_DOCTP_C_V.
* Table for entries selected to show on screen
DATA: BEGIN OF ZREING_DOCTP_C_V_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZREING_DOCTP_C_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_DOCTP_C_V_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZREING_DOCTP_C_V_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZREING_DOCTP_C_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_DOCTP_C_V_TOTAL.

*...processing: ZREING_DOCTP_R_V................................*
TABLES: ZREING_DOCTP_R_V, *ZREING_DOCTP_R_V. "view work areas
CONTROLS: TCTRL_ZREING_DOCTP_R_V
TYPE TABLEVIEW USING SCREEN '0002'.
DATA: BEGIN OF STATUS_ZREING_DOCTP_R_V. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZREING_DOCTP_R_V.
* Table for entries selected to show on screen
DATA: BEGIN OF ZREING_DOCTP_R_V_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZREING_DOCTP_R_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_DOCTP_R_V_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZREING_DOCTP_R_V_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZREING_DOCTP_R_V.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_DOCTP_R_V_TOTAL.

*.........table declarations:.................................*
TABLES: ZREING_DOCTYPE_C               .
TABLES: ZREING_DOCTYPE_R               .
