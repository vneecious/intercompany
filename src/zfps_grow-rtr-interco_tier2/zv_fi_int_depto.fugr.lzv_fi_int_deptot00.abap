*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZV_FI_INT_DEPTO.................................*
TABLES: ZV_FI_INT_DEPTO, *ZV_FI_INT_DEPTO. "view work areas
CONTROLS: TCTRL_ZV_FI_INT_DEPTO
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZV_FI_INT_DEPTO. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZV_FI_INT_DEPTO.
* Table for entries selected to show on screen
DATA: BEGIN OF ZV_FI_INT_DEPTO_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZV_FI_INT_DEPTO.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZV_FI_INT_DEPTO_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZV_FI_INT_DEPTO_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZV_FI_INT_DEPTO.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZV_FI_INT_DEPTO_TOTAL.

*.........table declarations:.................................*
TABLES: ZINT_A_MD_DPH                  .
