CLASS zcl_interco_utils DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    TYPES: ty_msehi TYPE msehi.

    CLASS-METHODS:
      get_instance
        RETURNING VALUE(ro_instance) TYPE REF TO zcl_interco_utils,
      rp_last_day_of_months
        IMPORTING !day_in                  TYPE sy-datum
*        EXPORTING !last_day_of_month TYPE sy-datum
        RETURNING VALUE(last_day_of_month) TYPE sy-datum
        RAISING   cx_sy_conversion_no_date,
      cunit_in
        IMPORTING VALUE(input)  TYPE any
                  !language     LIKE sy-langu DEFAULT sy-langu
        EXPORTING VALUE(output) TYPE any,
*        RAISING   cx_unit_conversion_failure,
      cunit_out
        IMPORTING VALUE(input)      TYPE any
                  !language         LIKE sy-langu DEFAULT sy-langu
        EXPORTING VALUE(long_text)  TYPE any
                  VALUE(output)     TYPE any
                  VALUE(short_text) TYPE any,
*        RAISING   cx_unit_conversion_failure,
      unit_code_outbound
        IMPORTING
          !im_value TYPE ty_msehi
        EXPORTING
          !ex_value TYPE csequence.
*        RAISING
*          cx_gdt_conversion .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA: go_instance TYPE REF TO zcl_interco_utils.
ENDCLASS.



CLASS zcl_interco_utils IMPLEMENTATION.
  METHOD rp_last_day_of_months.
    CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
      EXPORTING
        day_in            = day_in
      IMPORTING
        last_day_of_month = last_day_of_month
      EXCEPTIONS
        day_in_no_date    = 1
        OTHERS            = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_conversion_no_date
        EXPORTING
          textid = cx_sy_conversion_no_date=>cx_sy_conversion_no_date
          value  = CONV #( day_in ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance.

    ro_instance = COND #( WHEN zcl_interco_utils=>go_instance IS BOUND
                           THEN zcl_interco_utils=>go_instance
                         ELSE NEW zcl_interco_utils(  )  ).
    go_instance = ro_instance.
  ENDMETHOD.

  METHOD cunit_in.
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'
      EXPORTING
        input          = input
        language       = language
      IMPORTING
        output         = output
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc <> 0.
*     MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*       WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.
  ENDMETHOD.

  METHOD cunit_out.
    CALL FUNCTION 'CONVERSION_EXIT_CUNIT_OUTPUT'
      EXPORTING
        input          = input
        language       = language
      IMPORTING
        long_text      = long_text
        output         = output
        short_text     = short_text
      EXCEPTIONS
        unit_not_found = 1
        OTHERS         = 2.
    IF sy-subrc <> 0.
*     MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*       WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
    ENDIF.
  ENDMETHOD.

  METHOD unit_code_outbound.
    cl_gdt_conversion=>unit_code_outbound(
      EXPORTING
        im_value = im_value
      IMPORTING
        ex_value = ex_value
    ).
  ENDMETHOD.

ENDCLASS.
