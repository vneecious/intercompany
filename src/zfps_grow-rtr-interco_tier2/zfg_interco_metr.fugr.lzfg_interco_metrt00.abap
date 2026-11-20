*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_MD_METRIC................................*
DATA:  BEGIN OF STATUS_ZINT_A_MD_METRIC              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_MD_METRIC              .
CONTROLS: TCTRL_ZINT_A_MD_METRIC
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZINT_A_MD_METRIC              .
TABLES: ZINT_A_MD_METRIC               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
