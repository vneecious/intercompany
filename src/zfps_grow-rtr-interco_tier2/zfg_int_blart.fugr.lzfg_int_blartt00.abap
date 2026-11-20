*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_MD_BLART.................................*
DATA:  BEGIN OF STATUS_ZINT_A_MD_BLART               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_MD_BLART               .
CONTROLS: TCTRL_ZINT_A_MD_BLART
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZINT_A_MD_BLART               .
TABLES: ZINT_A_MD_BLART                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
