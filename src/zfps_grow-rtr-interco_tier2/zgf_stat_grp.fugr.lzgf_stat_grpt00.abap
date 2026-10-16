*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZFI_A_STAT_GRP..................................*
DATA:  BEGIN OF STATUS_ZFI_A_STAT_GRP                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZFI_A_STAT_GRP                .
CONTROLS: TCTRL_ZFI_A_STAT_GRP
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZFI_A_STAT_GRP                .
TABLES: ZFI_A_STAT_GRP                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
