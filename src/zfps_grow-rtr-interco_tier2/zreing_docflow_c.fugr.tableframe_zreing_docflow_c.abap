*---------------------------------------------------------------------*
*    program for:   TABLEFRAME_ZREING_DOCFLOW_C
*---------------------------------------------------------------------*
FUNCTION TABLEFRAME_ZREING_DOCFLOW_C   .

  PERFORM TABLEFRAME TABLES X_HEADER X_NAMTAB DBA_SELLIST DPL_SELLIST
                            EXCL_CUA_FUNCT
                     USING  CORR_NUMBER VIEW_ACTION VIEW_NAME.

ENDFUNCTION.
