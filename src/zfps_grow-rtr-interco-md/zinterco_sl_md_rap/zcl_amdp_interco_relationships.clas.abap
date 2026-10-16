CLASS zcl_amdp_interco_relationships DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.
    TYPES:
      BEGIN OF ty_draft,
        id         TYPE uuid,
        draft_uuid TYPE uuid,
      END OF ty_draft,
      ty_t_draft TYPE STANDARD TABLE OF ty_draft WITH NON-UNIQUE DEFAULT KEY.

    CLASS-METHODS:
      get_last_day
        IMPORTING
          VALUE(iv_date) TYPE datum
        EXPORTING
          VALUE(ev_date) TYPE datum
        RAISING
          cx_amdp_execution_failed,
      get_drafts_interco
        IMPORTING
          VALUE(iv_type)   TYPE zint_dte_uplt
        EXPORTING
          VALUE(et_drafts) TYPE ty_t_draft
        RAISING
          cx_amdp_execution_failed.

ENDCLASS.

CLASS zcl_amdp_interco_relationships IMPLEMENTATION.
  METHOD get_last_day BY DATABASE PROCEDURE
                      FOR HDB
                      LANGUAGE SQLSCRIPT
                      OPTIONS READ-ONLY.

    DECLARE lv_date "$ABAP.type( datum )";
    lv_date = :iv_date;

    lt_data = SELECT TO_CHAR( LAST_DAY (TO_DATE(:lv_date, 'YYYYMMDD')) , 'YYYYMMDD') as last_day,
                     TO_CHAR( CURRENT_DATE , 'YYYYMMDD') as curr_date
                    FROM DUMMY;

*    lt_format = SELECT TO_CHAR( last_day, 8 )
    ev_date = :lt_data.last_day[ 1 ];

  ENDMETHOD.

  METHOD get_drafts_interco BY DATABASE PROCEDURE
                      FOR HDB
                      LANGUAGE SQLSCRIPT
                      OPTIONS READ-ONLY
                      USING zint_d_md001.
    DECLARE lv_clnt "$ABAP.type( mandt )";
    lv_clnt := session_context('CLIENT');

    IF :iv_type = '1' THEN
        lt_data1 = SELECT
                       id,
                       DRAFTADMINISTRATIVEDATAUUID as draft_uuid,
                       CURRENT_TIMESTAMP as time1,
                       to_timestamp(DRAFTENTITYLASTCHANGEDATETIME) as time2
                   FROM zint_d_md001
                   WHERE mandt = :lv_clnt;
    END IF;

    lt_data2 = SELECT id,
                      draft_uuid,
                      time1 as current,
                      time2 as last_change,
                      floor(seconds_between( time2,time1 )/ 60) as duration
                FROM :lt_data1;

    lt_data3 = SELECT id,
                      draft_uuid,
                      current,
                      last_change,
                      duration
                FROM :lt_data2
                WHERE duration > 20;


    et_drafts = SELECT id, draft_uuid
                 FROM :lt_data3;

  ENDMETHOD.

ENDCLASS.
