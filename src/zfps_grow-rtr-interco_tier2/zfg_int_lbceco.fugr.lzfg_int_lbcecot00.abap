*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINT_A_MD_LBCECO................................*
DATA:  BEGIN OF STATUS_ZINT_A_MD_LBCECO              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINT_A_MD_LBCECO              .
CONTROLS: TCTRL_ZINT_A_MD_LBCECO
            TYPE TABLEVIEW USING SCREEN '0002'.
*.........table declarations:.................................*
TABLES: *ZINT_A_MD_LBCECO              .
TABLES: ZINT_A_MD_LBCECO               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
