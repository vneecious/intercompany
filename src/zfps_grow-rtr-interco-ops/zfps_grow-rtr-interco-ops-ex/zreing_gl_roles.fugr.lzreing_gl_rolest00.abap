*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_DOCTYPE_R................................*
DATA:  BEGIN OF STATUS_ZREING_DOCTYPE_R              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_DOCTYPE_R              .
CONTROLS: TCTRL_ZREING_DOCTYPE_R
            TYPE TABLEVIEW USING SCREEN '0004'.
*...processing: ZREING_OP_TYPE_T................................*
DATA:  BEGIN OF STATUS_ZREING_OP_TYPE_T              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_OP_TYPE_T              .
CONTROLS: TCTRL_ZREING_OP_TYPE_T
            TYPE TABLEVIEW USING SCREEN '0009'.
*...processing: ZREING_ROLE_OP..................................*
DATA:  BEGIN OF STATUS_ZREING_ROLE_OP                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_ROLE_OP                .
CONTROLS: TCTRL_ZREING_ROLE_OP
            TYPE TABLEVIEW USING SCREEN '0002'.
*.........table declarations:.................................*
TABLES: *ZREING_DOCTYPE_R              .
TABLES: *ZREING_OP_TYPE_T              .
TABLES: *ZREING_ROLE_OP                .
TABLES: ZREING_DOCTYPE_R               .
TABLES: ZREING_OP_TYPE_T               .
TABLES: ZREING_ROLE_OP                 .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
