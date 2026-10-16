*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZV_FI_INT_DEPTOI................................*
TABLES: ZV_FI_INT_DEPTOI, *ZV_FI_INT_DEPTOI. "view work areas
CONTROLS: TCTRL_ZV_FI_INT_DEPTOI
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZV_FI_INT_DEPTOI. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZV_FI_INT_DEPTOI.
* Table for entries selected to show on screen
DATA: BEGIN OF ZV_FI_INT_DEPTOI_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZV_FI_INT_DEPTOI.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZV_FI_INT_DEPTOI_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZV_FI_INT_DEPTOI_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZV_FI_INT_DEPTOI.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZV_FI_INT_DEPTOI_TOTAL.

*.........table declarations:.................................*
TABLES: ZINT_A_MD_DPI                  .
