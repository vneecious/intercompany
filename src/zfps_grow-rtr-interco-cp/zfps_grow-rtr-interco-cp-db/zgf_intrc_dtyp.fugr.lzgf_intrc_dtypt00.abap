*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZFI_A_INTRC_DTYP................................*
DATA:  BEGIN OF STATUS_ZFI_A_INTRC_DTYP              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZFI_A_INTRC_DTYP              .
CONTROLS: TCTRL_ZFI_A_INTRC_DTYP
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZFI_A_INTRC_DTYP              .
TABLES: ZFI_A_INTRC_DTYP               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
