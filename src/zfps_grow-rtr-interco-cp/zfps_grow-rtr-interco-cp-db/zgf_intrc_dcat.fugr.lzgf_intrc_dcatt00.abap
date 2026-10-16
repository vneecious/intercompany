*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZFI_A_INTRC_DCAT................................*
DATA:  BEGIN OF STATUS_ZFI_A_INTRC_DCAT              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZFI_A_INTRC_DCAT              .
CONTROLS: TCTRL_ZFI_A_INTRC_DCAT
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZFI_A_INTRC_DCAT              .
TABLES: ZFI_A_INTRC_DCAT               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
