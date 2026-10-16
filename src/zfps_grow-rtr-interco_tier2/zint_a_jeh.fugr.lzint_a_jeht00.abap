*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_JEH......................................*
DATA:  BEGIN OF STATUS_ZINT_A_JEH                    .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_JEH                    .
CONTROLS: TCTRL_ZINT_A_JEH
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZINT_A_JEH                    .
TABLES: ZINT_A_JEH                     .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
