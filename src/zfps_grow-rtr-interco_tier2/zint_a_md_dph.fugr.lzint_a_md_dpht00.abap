*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_MD_DPH...................................*
DATA:  BEGIN OF STATUS_ZINT_A_MD_DPH                 .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_MD_DPH                 .
CONTROLS: TCTRL_ZINT_A_MD_DPH
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZINT_A_MD_DPH                 .
TABLES: ZINT_A_MD_DPH                  .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
