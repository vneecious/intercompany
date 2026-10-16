CLASS zcl_interco_class_filter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES ty_pandl_range TYPE RANGE OF zi_intercojeitempandl-pandll0id.
    TYPES ty_glaccountparentnode_range TYPE RANGE OF zi_intercojeitempandl-glaccountparentnode.

    CLASS-METHODS get_active_pandll0_range
      RETURNING VALUE(rt_range) TYPE ty_pandl_range.

    "! <p>AGREGADO (fix performance): resuelve el rango de GLAccountParentNode (campo fisico,
    "! no calculado) que efectivamente mapea a un PandLL0Id activo en las reglas de clasificacion.
    "! Sirve para filtrar ANTES de los joins a Z_PNL_MT005 en materialize_agrupadores
    "! (ZCL_INTERCO_CLASS_ENGINE), en lugar de filtrar solo por PandLL0Id (columna calculada,
    "! que obliga a resolver el join completo para todas las lineas antes de poder filtrar).</p>
    CLASS-METHODS get_active_glparentnode_range
      RETURNING VALUE(rt_range) TYPE ty_glaccountparentnode_range.

ENDCLASS.



CLASS ZCL_INTERCO_CLASS_FILTER IMPLEMENTATION.


  METHOD get_active_pandll0_range.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    SELECT DISTINCT \_PandL-IDL0 AS pandll0id
      FROM zi_intercoclassificationrule
      WHERE isdeleted <> 'X'
        AND pandlid   IS NOT INITIAL
        AND validto   >= @lv_today
        AND validfrom <= @lv_today
      INTO TABLE @DATA(lt_l0_from_rules).
    rt_range = VALUE #(
      FOR lv_l0 IN lt_l0_from_rules
      ( sign = 'I' option = 'EQ' low = lv_l0-pandll0id ) ).
  ENDMETHOD.


  METHOD get_active_glparentnode_range.
    DATA(lt_l0_range) = get_active_pandll0_range( ).

    IF lt_l0_range IS INITIAL.
      RETURN.
    ENDIF.

    SELECT zagrup_cuentas, temp_zagrup_cuentas
      FROM z_pnl_mt005
      WHERE idl0 IN @lt_l0_range
      INTO TABLE @DATA(lt_mt005).

    rt_range = VALUE #(
      FOR ls_mt005 IN lt_mt005
      ( sign = 'I' option = 'EQ' low = CONV #( ls_mt005-zagrup_cuentas ) )
      ( sign = 'I' option = 'EQ' low = CONV #( ls_mt005-temp_zagrup_cuentas ) ) ).

    SORT rt_range.
    DELETE ADJACENT DUPLICATES FROM rt_range.
  ENDMETHOD.
ENDCLASS.
