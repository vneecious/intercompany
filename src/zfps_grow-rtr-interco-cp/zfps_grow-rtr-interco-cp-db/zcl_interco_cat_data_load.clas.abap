CLASS zcl_interco_cat_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_cat TYPE STANDARD TABLE OF zfi_a_intrc_dcat,
      ty_typ TYPE STANDARD TABLE OF zfi_a_intrc_dtyp,
      ty_grp TYPE STANDARD TABLE OF zfi_a_stat_grp,
      ty_sts TYPE STANDARD TABLE OF zfi_a_cph_stat.

    CLASS-METHODS clean_table .
    CLASS-METHODS load_data
      IMPORTING
        !it_cat       TYPE ty_cat
        !it_typ       TYPE ty_typ
        !it_grp       TYPE ty_grp
        !it_sts       TYPE ty_sts
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_cat_data_load IMPLEMENTATION.
  METHOD clean_table.
    DELETE FROM zfi_a_intrc_dcat WHERE cat_id IS NOT INITIAL.
    DELETE FROM zfi_a_intrc_dtyp WHERE dtyp_id IS NOT INITIAL.
    DELETE FROM zfi_a_stat_grp WHERE status_grp IS NOT INITIAL.
    DELETE FROM zfi_a_cph_stat WHERE status IS NOT INITIAL.
    COMMIT WORK.
  ENDMETHOD.

  METHOD load_data.
    DATA: lt_cat TYPE ty_cat,
          lt_typ TYPE ty_typ,
          lt_grp TYPE ty_grp,
          lt_sts TYPE ty_sts.

    lt_cat = it_cat.
    lt_typ = it_typ.
    lt_grp = it_grp.
    lt_sts = it_sts.

    MODIFY zfi_a_intrc_dcat FROM TABLE @lt_cat.
    MODIFY zfi_a_intrc_dtyp FROM TABLE @lt_typ.
    MODIFY zfi_a_stat_grp FROM TABLE @lt_grp.
    MODIFY zfi_a_cph_stat FROM TABLE @lt_sts.
    COMMIT WORK.

    rv_len = lines( lt_cat ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_cat TYPE STANDARD TABLE OF zfi_a_intrc_dcat,
          lt_typ TYPE STANDARD TABLE OF zfi_a_intrc_dtyp,
          lt_grp TYPE STANDARD TABLE OF zfi_a_stat_grp,
          lt_sts TYPE STANDARD TABLE OF zfi_a_cph_stat.

    APPEND VALUE #( cat_id = 1 language_code = 'E' cat_name = 'Interdivision' col_pos = 1 ) TO lt_cat.
    APPEND VALUE #( cat_id = 2 language_code = 'E' cat_name = 'Orders' col_pos = 2 ) TO lt_cat.
    APPEND VALUE #( cat_id = 3 language_code = 'E' cat_name = 'Invoicing' col_pos = 3 ) TO lt_cat.
    APPEND VALUE #( cat_id = 4 language_code = 'E' cat_name = 'Reclasification' col_pos = 4 ) TO lt_cat.
    APPEND VALUE #( cat_id = 1 language_code = 'S' cat_name = 'Interdivision' col_pos = 1 ) TO lt_cat.
    APPEND VALUE #( cat_id = 2 language_code = 'S' cat_name = 'Pedidos' col_pos = 2 ) TO lt_cat.
    APPEND VALUE #( cat_id = 3 language_code = 'S' cat_name = 'Factruras' col_pos = 3 ) TO lt_cat.
    APPEND VALUE #( cat_id = 4 language_code = 'S' cat_name = 'Reclasificación' col_pos = 4 ) TO lt_cat.


    APPEND VALUE #( dtyp_id = 10  language_code = 'E' dtyp_name = 'Interdivision' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 20  language_code = 'E' dtyp_name = 'Sales Order' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 30  language_code = 'E' dtyp_name = 'Billing Document' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 40  language_code = 'E' dtyp_name = 'Purchase Order' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 50  language_code = 'E' dtyp_name = 'Supplier Invoice' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 60  language_code = 'E' dtyp_name = 'Income Reclasification' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 70  language_code = 'E' dtyp_name = 'Expenses Reclasification' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 80  language_code = 'E' dtyp_name = 'Journal Entry Account Recivable' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 90  language_code = 'E' dtyp_name = 'Journal Entry Account Paylable' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 100 language_code = 'E' dtyp_name = 'Anulation Interdiv.' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 110 language_code = 'E' dtyp_name = 'Anulation Sales Order' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 120 language_code = 'E' dtyp_name = 'Anulation Billing Doc.' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 130 language_code = 'E' dtyp_name = 'Anulation JE Sales' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 140 language_code = 'E' dtyp_name = 'Anulation Purchase' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 150 language_code = 'E' dtyp_name = 'Anulation Supplier Inv.' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 160 language_code = 'E' dtyp_name = 'Anulation JE Purchase' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 170 language_code = 'E' dtyp_name = 'Anulation Income Recl.' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 180 language_code = 'E' dtyp_name = 'Anulation Expenses Recl.' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 10  language_code = 'S' dtyp_name = 'Interdivision' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 20  language_code = 'S' dtyp_name = 'Pedidos de venta' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 30  language_code = 'S' dtyp_name = 'Factura de venta' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 40  language_code = 'S' dtyp_name = 'Pedidos de compra' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 50  language_code = 'S' dtyp_name = 'Factura de compra' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 60  language_code = 'S' dtyp_name = 'Reclasificación de ingresos' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 70  language_code = 'S' dtyp_name = 'Reclasificación de gastos' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 80  language_code = 'S' dtyp_name = 'Doc. FI Cuentas por cobrar' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 90  language_code = 'S' dtyp_name = 'Doc. FI Cuentas por pagar' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 100 language_code = 'S' dtyp_name = 'Anulacion Interdiv.' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 110 language_code = 'S' dtyp_name = 'Anulacion Ord. Venta' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 120 language_code = 'S' dtyp_name = 'Anulacion Fact. Venta' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 130 language_code = 'S' dtyp_name = 'Anulacion Doc. FI Venta' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 140 language_code = 'S' dtyp_name = 'Anulacion Ord. Compra' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 150 language_code = 'S' dtyp_name = 'Anulacion Fact. Compra' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 160 language_code = 'S' dtyp_name = 'Anulacion Doc. FI Compra' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 170 language_code = 'S' dtyp_name = 'Anulacion Recl. Ingresos' ) TO lt_typ.
    APPEND VALUE #( dtyp_id = 180 language_code = 'S' dtyp_name = 'Anulacion Recl. Gastos' ) TO lt_typ.


    APPEND VALUE #( status_grp = 'W' langu = 'S' stat_grp_name = 'Acción Requerida' ) TO lt_grp.
    APPEND VALUE #( status_grp = ''  langu = 'S' stat_grp_name = 'En ejecución' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'E' langu = 'S' stat_grp_name = 'Error' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'S' langu = 'S' stat_grp_name = 'Finalizado' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'W' langu = 'E' stat_grp_name = 'Action Required' ) TO lt_grp.
    APPEND VALUE #( status_grp = ''  langu = 'E' stat_grp_name = 'On Execution' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'E' langu = 'E' stat_grp_name = 'Error' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'S' langu = 'E' stat_grp_name = 'Finished' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'W' langu = 'P' stat_grp_name = 'Ação necessária' ) TO lt_grp.
    APPEND VALUE #( status_grp = ''  langu = 'P' stat_grp_name = 'Em andamento' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'E' langu = 'P' stat_grp_name = 'Erro' ) TO lt_grp.
    APPEND VALUE #( status_grp = 'S' langu = 'P' stat_grp_name = 'Finalizado' ) TO lt_grp.


    APPEND VALUE #( status = ' ' grp1 = 'W' critic_1 = 2 ) TO lt_sts.
    APPEND VALUE #( status = 'V' grp1 = 'W' critic_1 = 2 ) TO lt_sts.
    APPEND VALUE #( status = 'C' grp1 = 'W' critic_1 = 2 ) TO lt_sts.
    APPEND VALUE #( status = 'S' grp1 = ''  critic_1 = 0 ) TO lt_sts.
    APPEND VALUE #( status = 'P' grp1 = ''  critic_1 = 0 ) TO lt_sts.
    APPEND VALUE #( status = 'T' grp1 = ''  critic_1 = 0 ) TO lt_sts.
    APPEND VALUE #( status = 'N' grp1 = ''  critic_1 = 0 ) TO lt_sts.
    APPEND VALUE #( status = 'D' grp1 = ''  critic_1 = 0 ) TO lt_sts.
    APPEND VALUE #( status = 'B' grp1 = ''  critic_1 = 0 ) TO lt_sts.
    APPEND VALUE #( status = 'F' grp1 = 'E' critic_1 = 1 ) TO lt_sts.
    APPEND VALUE #( status = 'O' grp1 = 'E' critic_1 = 1 ) TO lt_sts.
    APPEND VALUE #( status = 'E' grp1 = 'E' critic_1 = 1 ) TO lt_sts.
    APPEND VALUE #( status = 'I' grp1 = 'S' critic_1 = 3 ) TO lt_sts.
    APPEND VALUE #( status = 'A' grp1 = 'S' critic_1 = 3 ) TO lt_sts.
    APPEND VALUE #( status = 'R' grp1 = 'S' critic_1 = 3 ) TO lt_sts.

    zcl_interco_cat_data_load=>clean_table(  ).
    DATA(lv_len) = zcl_interco_cat_data_load=>load_data( it_cat = lt_cat
                                                         it_typ = lt_typ
                                                         it_grp = lt_grp
                                                         it_sts = lt_sts ).
    out->write( |Total de registros carregados na zfi_a_intrc_dcat: { lv_len }.| ).

  ENDMETHOD.

ENDCLASS.
