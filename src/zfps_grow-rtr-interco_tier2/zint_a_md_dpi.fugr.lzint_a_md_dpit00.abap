*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_MD_DPI...................................*
DATA:  BEGIN OF STATUS_ZINT_A_MD_DPI                 .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_MD_DPI                 .
CONTROLS: TCTRL_ZINT_A_MD_DPI
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZINT_A_MD_DPI                 .
TABLES: ZINT_A_MD_DPI                  .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
