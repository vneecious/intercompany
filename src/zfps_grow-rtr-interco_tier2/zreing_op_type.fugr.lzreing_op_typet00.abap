*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_OP_TYPES.................................*
DATA:  BEGIN OF STATUS_ZREING_OP_TYPES               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_OP_TYPES               .
CONTROLS: TCTRL_ZREING_OP_TYPES
            TYPE TABLEVIEW USING SCREEN '0003'.
*...processing: ZREING_OP_TYP_CV................................*
TABLES: ZREING_OP_TYP_CV, *ZREING_OP_TYP_CV. "view work areas
CONTROLS: TCTRL_ZREING_OP_TYP_CV
TYPE TABLEVIEW USING SCREEN '0001'.
DATA: BEGIN OF STATUS_ZREING_OP_TYP_CV. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZREING_OP_TYP_CV.
* Table for entries selected to show on screen
DATA: BEGIN OF ZREING_OP_TYP_CV_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZREING_OP_TYP_CV.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_OP_TYP_CV_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZREING_OP_TYP_CV_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZREING_OP_TYP_CV.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_OP_TYP_CV_TOTAL.

*...processing: ZREING_OP_TYP_TV................................*
TABLES: ZREING_OP_TYP_TV, *ZREING_OP_TYP_TV. "view work areas
CONTROLS: TCTRL_ZREING_OP_TYP_TV
TYPE TABLEVIEW USING SCREEN '0002'.
DATA: BEGIN OF STATUS_ZREING_OP_TYP_TV. "state vector
          INCLUDE STRUCTURE VIMSTATUS.
DATA: END OF STATUS_ZREING_OP_TYP_TV.
* Table for entries selected to show on screen
DATA: BEGIN OF ZREING_OP_TYP_TV_EXTRACT OCCURS 0010.
INCLUDE STRUCTURE ZREING_OP_TYP_TV.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_OP_TYP_TV_EXTRACT.
* Table for all entries loaded from database
DATA: BEGIN OF ZREING_OP_TYP_TV_TOTAL OCCURS 0010.
INCLUDE STRUCTURE ZREING_OP_TYP_TV.
          INCLUDE STRUCTURE VIMFLAGTAB.
DATA: END OF ZREING_OP_TYP_TV_TOTAL.

*.........table declarations:.................................*
TABLES: *ZREING_OP_TYPES               .
TABLES: ZREING_OP_TYPES                .
TABLES: ZREING_OP_TYPE_C               .
TABLES: ZREING_OP_TYPE_T               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
