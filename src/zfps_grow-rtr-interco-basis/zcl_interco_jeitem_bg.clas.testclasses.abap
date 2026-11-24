*"* use this source file for your ABAP unit test classes

"! EXT_VINBARRI 17.11.2026: lista de columnas del background (build_field_list).
CLASS ltc_build_field_list DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS empty_returns_all FOR TESTING.
    METHODS mandatory_always_included FOR TESTING.
    METHODS requested_column_included FOR TESTING.
    METHODS unknown_and_injection_ignored FOR TESTING.
    METHODS no_duplicates FOR TESTING.
    METHODS list_is_valid_in_select FOR TESTING.
    METHODS split
      IMPORTING iv_fields        TYPE string
      RETURNING VALUE(rt_fields) TYPE string_table.
ENDCLASS.

CLASS ltc_build_field_list IMPLEMENTATION.

  METHOD split.
    SPLIT iv_fields AT `, ` INTO TABLE rt_fields.
  ENDMETHOD.

  METHOD empty_returns_all.
    " Sin columnas informadas (UI anterior) se graba todo, como antes
    cl_abap_unit_assert=>assert_equals( act = zcl_interco_jeitem_bg=>build_field_list( `` )
                                        exp = `*` ).
  ENDMETHOD.

  METHOD mandatory_always_included.
    DATA(lt_fields) = split( zcl_interco_jeitem_bg=>build_field_list( `GLAccount` ) ).
    DATA(lt_mandatory) = VALUE string_table(
      ( `COMPANYCODE` ) ( `FISCALYEAR` ) ( `FISCALPERIOD` ) ( `ACCOUNTINGDOCUMENT` )
      ( `LEDGERGLLINEITEM` ) ( `LEDGER` ) ( `SOURCELEDGER` ) ( `PAYMENTTYPE` )
      ( `CCALLOCATION` ) ( `CCCONSOLIDATION` )
      ( `PANDLL0ID` ) ( `PANDLL1ID` ) ( `PANDLL2ID` ) ( `PANDLL3ID` ) ( `PANDLL4ID` ) ( `PANDLL5ID` )
      ( `GLACCOUNT` ) ( `COSTCENTERSTANDARDHIERAREA` ) ( `DEPARTMENT` ) ( `CONCEPT` )
      ( `COSTCENTER` ) ( `PROFITCENTER` )
      ( `COMPANYCODECURRENCY` ) ( `AMOUNTINCOMPANYCODECURRENCY` )
      ( `GLOBALCURRENCY` ) ( `AMOUNTINGLOBALCURRENCY` )
      ( `CREATIONDATETIME` ) ( `ISBILLABLE` ) ).
    LOOP AT lt_mandatory INTO DATA(lv_field).
      cl_abap_unit_assert=>assert_table_contains( line  = lv_field
                                                  table = lt_fields
                                                  msg   = |Falta campo obligatorio { lv_field }| ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lines( lt_fields ) exp = lines( lt_mandatory )
                                        msg = |Lista minima inesperada: { concat_lines_of( table = lt_fields sep = `,` ) }| ).
  ENDMETHOD.

  METHOD requested_column_included.
    DATA(lt_fields) = split( zcl_interco_jeitem_bg=>build_field_list( ` PandLL0Name , RuleName` ) ).
    cl_abap_unit_assert=>assert_table_contains( line = `PANDLL0NAME` table = lt_fields ).
    cl_abap_unit_assert=>assert_table_contains( line = `RULENAME` table = lt_fields ).
    cl_abap_unit_assert=>assert_table_not_contains( line = `INDEXTOTAL` table = lt_fields ).
  ENDMETHOD.

  METHOD unknown_and_injection_ignored.
    " IsReleased no existe en ZINT_A_JEI; IsBillableFilter no existe en la V4; el resto es basura/inyeccion
    DATA(lv_fields) = zcl_interco_jeitem_bg=>build_field_list( `IsReleased,IsBillableFilter,FOO,GLACCOUNT) OR (1 = 1` ).
    DATA(lt_fields) = split( lv_fields ).
    cl_abap_unit_assert=>assert_table_not_contains( line = `ISRELEASED` table = lt_fields ).
    cl_abap_unit_assert=>assert_table_not_contains( line = `ISBILLABLEFILTER` table = lt_fields ).
    cl_abap_unit_assert=>assert_table_not_contains( line = `FOO` table = lt_fields ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( lv_fields CA '()=' )
                                       msg = |Lista con caracteres no permitidos: { lv_fields }| ).
  ENDMETHOD.

  METHOD no_duplicates.
    DATA(lt_fields) = split( zcl_interco_jeitem_bg=>build_field_list( `CompanyCode,companycode,GLACCOUNT` ) ).
    DATA(lt_unique) = lt_fields.
    SORT lt_unique.
    DELETE ADJACENT DUPLICATES FROM lt_unique.
    cl_abap_unit_assert=>assert_equals( act = lines( lt_fields ) exp = lines( lt_unique ) ).
  ENDMETHOD.

  METHOD list_is_valid_in_select.
    " Mismo patron del background: FROM dinamico sobre la V4 + FIELDS dinamico -> ZINT_A_JEI.
    " Valida la sentencia (no dispara CX_SY_DYNAMIC_OSQL_*); el resultado depende de los datos.
    DATA lt_jei TYPE TABLE OF zint_a_jei.
    DATA(lv_source) = |zc_intercojeitemclassv4( p_companycode = 'CMC', p_ledger = '0L', p_fiscalyear = '2026', | &&
                      |p_fiscalperiod = '001', p_paymenttype = 'E' )|.
    DATA(lv_fields) = zcl_interco_jeitem_bg=>build_field_list( `GLAccount,PandLL0Name,IsBillableText,AREA_2,Campana,IdBase` ).
    TRY.
        SELECT FROM (lv_source) FIELDS (lv_fields)
          INTO CORRESPONDING FIELDS OF TABLE @lt_jei
          UP TO 1 ROWS.
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |SELECT dinamico fallo: { lx_error->get_text( ) } / { lv_fields }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
