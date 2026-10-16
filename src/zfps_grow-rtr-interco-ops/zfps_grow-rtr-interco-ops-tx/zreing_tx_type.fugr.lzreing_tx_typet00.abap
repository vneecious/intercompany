*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_TX_TYPE_C................................*
DATA:  BEGIN OF STATUS_ZREING_TX_TYPE_C              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_TX_TYPE_C              .
CONTROLS: TCTRL_ZREING_TX_TYPE_C
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZREING_TX_TYPE_C              .
TABLES: ZREING_TX_TYPE_C               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
