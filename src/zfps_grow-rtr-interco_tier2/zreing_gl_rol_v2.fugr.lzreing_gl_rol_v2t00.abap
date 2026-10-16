*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZREING_GL_ROLES.................................*
DATA:  BEGIN OF STATUS_ZREING_GL_ROLES               .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZREING_GL_ROLES               .
CONTROLS: TCTRL_ZREING_GL_ROLES
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZREING_GL_ROLES               .
TABLES: ZREING_GL_ROLES                .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
