CLASS zcl_check_interco_oauth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CONSTANTS: gc_admin   TYPE zint_dte_agr_name VALUE 'ZINTERCO_ADMIN',
               gc_manager TYPE zint_dte_agr_name VALUE 'ZINTERCO_MANAGER',
               gc_user    TYPE zint_dte_agr_name VALUE 'ZINTERCO_USER'.

    DATA: gt_roles TYPE STANDARD TABLE OF zr_usersroles.

    METHODS: constructor IMPORTING iv_user           TYPE zint_dte_xubname.

    METHODS: check_admin RETURNING VALUE(rv_request) TYPE abap_bool.
    METHODS: check_manager RETURNING VALUE(rv_request) TYPE abap_bool.
    METHODS: check_user RETURNING VALUE(rv_request) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_check_interco_oauth IMPLEMENTATION.
  METHOD constructor.
    SELECT AgrName, Uname, FromDat, ToDat
      FROM zr_usersroles
      WHERE Uname = @iv_user
      INTO TABLE @gt_roles.

  ENDMETHOD.

  METHOD check_admin.

    READ TABLE gt_roles TRANSPORTING NO FIELDS WITH KEY agrname = gc_admin BINARY SEARCH.
    IF  sy-subrc EQ 0.
      rv_request = if_abap_behv=>auth-allowed.
    ELSE.
      rv_request = if_abap_behv=>auth-unauthorized.
    ENDIF.

  ENDMETHOD.

  METHOD check_manager.
    READ TABLE gt_roles TRANSPORTING NO FIELDS WITH KEY agrname = gc_manager BINARY SEARCH.
    IF  sy-subrc EQ 0.
      rv_request = if_abap_behv=>auth-allowed.
    ELSE.
      rv_request = if_abap_behv=>auth-unauthorized.
    ENDIF.
  ENDMETHOD.

  METHOD check_user.
    READ TABLE gt_roles TRANSPORTING NO FIELDS WITH KEY agrname = gc_user BINARY SEARCH.
    IF  sy-subrc EQ 0.
      rv_request = if_abap_behv=>auth-allowed.
    ELSE.
      rv_request = if_abap_behv=>auth-unauthorized.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
