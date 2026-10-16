*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_DOCFLOW_C................................*
DATA:  BEGIN OF STATUS_ZREING_DOCFLOW_C              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_DOCFLOW_C              .
CONTROLS: TCTRL_ZREING_DOCFLOW_C
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZREING_DOCFLOW_C              .
TABLES: ZREING_DOCFLOW_C               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
