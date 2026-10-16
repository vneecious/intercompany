*---------------------------------------------------------------------*
*    program for:   TABLEFRAME_ZVINT_A_FEATUR
*---------------------------------------------------------------------*
FUNCTION TABLEFRAME_ZVINT_A_FEATUR     .

  PERFORM TABLEFRAME TABLES X_HEADER X_NAMTAB DBA_SELLIST DPL_SELLIST
                            EXCL_CUA_FUNCT
                     USING  CORR_NUMBER VIEW_ACTION VIEW_NAME.

ENDFUNCTION.
