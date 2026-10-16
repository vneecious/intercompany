*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZFI_A_CPH_STAT..................................*
DATA:  BEGIN OF STATUS_ZFI_A_CPH_STAT                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZFI_A_CPH_STAT                .
CONTROLS: TCTRL_ZFI_A_CPH_STAT
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZFI_A_CPH_STAT                .
TABLES: ZFI_A_CPH_STAT                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
