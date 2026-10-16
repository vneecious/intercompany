*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZINTER_WHT_ZUONR................................*
DATA:  BEGIN OF STATUS_ZINTER_WHT_ZUONR              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZINTER_WHT_ZUONR              .
CONTROLS: TCTRL_ZINTER_WHT_ZUONR
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZINTER_WHT_ZUONR              .
TABLES: ZINTER_WHT_ZUONR               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
