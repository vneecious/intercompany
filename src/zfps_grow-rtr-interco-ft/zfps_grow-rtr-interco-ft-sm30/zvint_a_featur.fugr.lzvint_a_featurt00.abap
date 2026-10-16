*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_FEATURE..................................*
DATA:  BEGIN OF STATUS_ZINT_A_FEATURE                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_FEATURE                .
CONTROLS: TCTRL_ZINT_A_FEATURE
            TYPE TABLEVIEW USING SCREEN '0003'.
*...processing: ZVINT_A_FEATURE.................................*
TABLES: ZVINT_A_FEATURE, *ZVINT_A_FEATURE. "view work areas
CONTROLS: TCTRL_ZVINT_A_FEATURE
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZVINT_A_FEATURE. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZVINT_A_FEATURE.
* Table for entries selected to show on screen
DATA: BEGIN OF ZVINT_A_FEATURE_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZVINT_A_FEATURE.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZVINT_A_FEATURE_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZVINT_A_FEATURE_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZVINT_A_FEATURE.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZVINT_A_FEATURE_TOTAL.

*.........table declarations:.................................*
TABLES: *ZINT_A_FEATURE                .
TABLES: ZINT_A_FEATURE                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
